// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_RebasingAwareERC4626} from "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {Phase_07_Stage_02_FeeAccrualCustodySe as Custody} from "scripts/foundry/anvil_robinhood_main/Phase_07_Stage_02_FeeAccrualCustodySe.sol";
import {Phase_07_Stage_03_FeeAccrualRateProviders as Providers} from "scripts/foundry/anvil_robinhood_main/Phase_07_Stage_03_FeeAccrualRateProviders.sol";
import {Phase_05_Stage_01_SeRateProviderPkg as ProviderPackage} from "scripts/foundry/anvil_robinhood_main/Phase_05_Stage_01_SeRateProviderPkg.sol";
import {LaunchState} from "scripts/foundry/anvil_robinhood_main/LaunchState.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeRateQuote, IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

/// @notice Registered production wrapper/provider execution through the same deployment libraries.
contract FeeAccrualCustodyScript is TestBase_RebasingAwareERC4626 {
    LaunchState internal launch;

    function setUp() public override {
        super.setUp();
        launch.create3Factory = create3Factory;
        launch.diamondPackageFactory = diamondPackageFactory;
        ProviderPackage.execute(launch);
    }

    function test_custodyScript_registeredDeterministicReuse() public {
        bytes32 salt = keccak256("fee-accrual-custody");
        address custody = Custody.execute(address(indexedexManager), diamondPackageFactory, pkg, IERC20Metadata(address(asset)), 10, salt);
        assertTrue(custody != address(vault), "separate custody instance");
        assertEq(IERC20Metadata(custody).decimals(), 28);
        assertEq(Custody.execute(address(indexedexManager), diamondPackageFactory, pkg, IERC20Metadata(address(asset)), 10, salt), custody);
        assertEq(pkg.vaultFeeTypeIds(), bytes32(0));
    }

    function test_custodyProvider_normalizesWholeSharesAndTracksDonations() public {
        address custody = Custody.execute(address(indexedexManager), diamondPackageFactory, pkg, IERC20Metadata(address(asset)), 10, keccak256("fee-provider"));
        address provider = Providers.execute(diamondPackageFactory, launch.rateProviderPkg, custody, address(asset));
        assertEq(IRateProvider(provider).getRate(), 0, "unfunded provider is zero");
        vm.startPrank(alice);
        asset.approve(custody, 1 ether);
        assertEq(IERC4626(custody).deposit(1 ether, alice), 1e28, "one displayed share");
        vm.stopPrank();
        assertEq(IRateProvider(provider).getRate(), 1 ether, "DTF per whole 28-decimal share");
        vm.prank(bob);
        asset.transfer(custody, 1 ether);
        uint256 rate = IRateProvider(provider).getRate();
        assertEq(rate, IERC4626(custody).previewRedeem(1e28));
        assertGt(rate, 1 ether, "backing-sensitive, not constant");
        assertEq(Providers.execute(diamondPackageFactory, launch.rateProviderPkg, custody, address(asset)), provider);
    }

    function test_custodyProvider_projectedDepositMatchesLiveRate() public {
        address custody = Custody.execute(address(indexedexManager), diamondPackageFactory, pkg, IERC20Metadata(address(asset)), 10, keccak256("fee-projection"));
        address provider = Providers.execute(diamondPackageFactory, launch.rateProviderPkg, custody, address(asset));
        vm.startPrank(alice);
        asset.approve(custody, 2 ether);
        IERC4626(custody).deposit(1 ether, alice);
        vm.stopPrank();
        IStandardExchangeTransitionQuote exchange = IStandardExchangeTransitionQuote(custody);
        (bytes memory state,) = exchange.quoteState(address(asset), alice);
        (state,,,) = exchange.quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, 1 ether);
        uint256 projected = IStandardExchangeRateQuote(provider).quoteRate(custody, address(asset), state);
        vm.prank(alice);
        IERC4626(custody).deposit(1 ether, alice);
        assertEq(IRateProvider(provider).getRate(), projected);
    }
}
