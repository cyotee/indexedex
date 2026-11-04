// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {IUniswapV4PairTokenStandardExchangeVaultComponentBindings as IBindings} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol";
import {UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService as Components} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultMath as Math} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultMath.sol";
import {
    UniswapV4PairTokenStandardExchangeVaultProjection as Projection,
    UniswapV4PairTokenStandardExchangeVaultSwapProjection as SwapProjection
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {UniswapV4PairTokenStandardExchangeVaultPlanner as Planner} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultPlanner.sol";
import {
    UniswapV4PairTokenStandardExchangeVaultExecution as Execution,
    UniswapV4PairTokenStandardExchangeVaultExecutionPreparation as Preparation
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";

/// @notice Normal code limits and measured cold-call gas, not an invented network budget.
/// @dev A70 stays open until an owner-supplied transaction and eth_call envelope
/// is compared with these observations. No profile or work limit is relaxed here.
// tag::UniswapV4PairTokenStandardExchangeVaultFeasibilityTest[]
contract UniswapV4PairTokenStandardExchangeVaultFeasibilityTest is
    TestBase_UniswapV4PairTokenStandardExchangeVault
{
    using PoolIdLibrary for PoolKey;
    function test_GAS_RuntimeSizeEveryShippedComponent() public view {
        address[] memory facets_ = pairTokenPackage.facetAddresses();
        for (uint256 i_ = 0; i_ < facets_.length; ++i_) _size(facets_[i_]);
        _size(address(pairTokenPackage));
        for (uint256 i_ = 0; i_ < 6; ++i_) _size(pkgInit.linkedLibraries[i_]);
        assertEq(
            IDiamondLoupe(address(vault)).facetAddress(IBindings.linkedComponents.selector), address(0),
            "binding metadata is not a product route"
        );
        for (uint256 i_ = 5; i_ < facets_.length; ++i_) {
            assertEq(abi.encode(IBindings(facets_[i_]).linkedComponents()), abi.encode(pkgInit.linkedLibraries));
        }
        string memory json_ = vm.readFile(
            "out/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol/UniswapV4PairTokenStandardExchangeVaultDFPkg.json"
        );
        uint256 creation_ = (bytes(vm.parseJsonString(json_, ".bytecode.object")).length - 2) / 2;
        assertLe(creation_ + abi.encode(pkgInit).length, 49152, "package initcode plus constructor arguments");
    }

    function test_GAS_AllLinkedComponentsRejectDirectExecution() public {
        Types.ProjectedState memory projected_;
        Types.Snapshot memory snapshot_;
        Types.Operation memory operation_;
        Execution.Request memory request_;
        _direct(pkgInit.linkedLibraries[0],
            abi.encodeWithSelector(Math.principal.selector, uint160(1 << 96), uint160(1 << 95), uint160(1 << 97), uint128(1)),
            abi.encodeWithSelector(Math.DirectCallNotAllowed.selector));
        _direct(pkgInit.linkedLibraries[1], abi.encodeWithSelector(Projection.capture.selector, projected_),
            abi.encodeWithSelector(Projection.DirectCallNotAllowed.selector));
        _direct(pkgInit.linkedLibraries[2],
            abi.encodeWithSelector(SwapProjection.projectSwap.selector, projected_, true, uint256(1), uint160(1), Types.Phase.EntrySwap),
            abi.encodeWithSelector(Projection.DirectCallNotAllowed.selector));
        _direct(pkgInit.linkedLibraries[3], abi.encodeWithSelector(Planner.plan.selector, snapshot_, operation_),
            abi.encodeWithSelector(Planner.DirectCallNotAllowed.selector));
        _direct(pkgInit.linkedLibraries[4], abi.encodeWithSelector(Execution.donate.selector, address(token0), uint256(1)), "");
        _direct(pkgInit.linkedLibraries[5], abi.encodeWithSelector(Preparation.prepare.selector, request_), "");
    }

    function test_GAS_OccupiedPackageCannotSilentlyRebindLibraries() public {
        IPackage.PkgInit memory changed_ = pkgInit;
        changed_.linkedLibraries[0] = changed_.linkedLibraries[1];
        bytes32 before_ = pairTokenPackage.bindingHash();
        vm.expectRevert(abi.encodeWithSelector(Components.PackageBindingMismatch.selector, address(pairTokenPackage)));
        this.deployPackageForControl(changed_);
        assertEq(pairTokenPackage.bindingHash(), before_);
    }

    function test_GAS_OccupiedFacetCannotSilentlyReuseDifferentCode() public {
        assertTrue(vm.revertToState(componentDeploymentSnapshot));
        bytes memory otherCode_ = ArtifactCreationCode.creationCode(create3Factory,
            "UniswapV4PairTokenStandardExchangeVaultOutFacet.sol:UniswapV4PairTokenStandardExchangeVaultOutFacet");
        IFacet occupied_ = create3Factory.deployFacet(otherCode_,
            keccak256(abi.encode("UniswapV4PairTokenStandardExchangeVaultMoneyFacet")));
        vm.expectRevert(abi.encodeWithSelector(Components.RuntimeArtifactMismatch.selector, address(occupied_)));
        this.deployMoneyForControl();
    }

    /// @dev External boundary lets expectRevert observe the entire Foundry helper,
    /// rather than its first successful artifact/factory subcall.
    function deployPackageForControl(IPackage.PkgInit memory init_) external {
        vm.prank(owner);
        Components.deployUniswapV4PairTokenStandardExchangeVaultDFPkg(indexedexManager, init_);
    }

    function deployMoneyForControl() external {
        Components.deployMoneyFacet(create3Factory);
    }

    function test_GAS_NormalPreviewAndExecutionColdCalls() public {
        _fund(address(this), 2e18, 2e18);
        _approveVault(address(vault));
        _cold();
        uint256 start_ = gasleft();
        (uint256 shares_,,) = vault.previewDepositPair(1e18, 1e18);
        _gas("gas.genesis.preview.cold", start_, 5_000_000);
        _cold();
        start_ = gasleft();
        assertEq(vault.depositPair(1e18, 1e18, shares_, address(this), block.timestamp), shares_);
        _gas("gas.genesis.execute.cold", start_, 11_900_000);
        vault.donate(address(token0), 1e13);
        _cold();
        start_ = gasleft();(uint256 quote_,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(token0)), 1e14, IERC20(address(vault))
        );
        _gas("gas.zap.preview.cold", start_, 5_000_000);
        _cold();
        start_ = gasleft();
        assertEq(ExchangeInAmount.exchangeOut(IStandardExchangeIn(address(IStandardExchangeIn(address(vault)))), IERC20(address(token0)), 1e14, IERC20(address(vault)), quote_, address(this), false, block.timestamp
        ), quote_);
        _gas("gas.zap.execute.cold", start_, 11_900_000);
        _cold();
        start_ = gasleft();
        (uint256 amount0_, uint256 amount1_) = vault.previewRedeemPair(shares_ / 10);
        _gas("gas.pairExit.preview.cold", start_, 5_000_000);
        _cold();
        start_ = gasleft();
        vault.redeemPair(shares_ / 10, amount0_, amount1_, address(this), block.timestamp);
        _gas("gas.pairExit.execute.cold", start_, 11_900_000);
    }

    function test_GAS_NativeAndWrappedColdCalls() public {
        _deployPool(true, 18, 18);
        vault = _deployVault(_defaultArgs(key, address(wrappedNative), "Gas native vault"));
        _bootstrap(1e18, 1e18, address(this));
        vm.deal(address(this), address(this).balance + 1e15);
        _cold();
        uint256 start_ = gasleft();
        uint256 quote_ = IStandardizedYield(address(vault)).previewDeposit(address(0), 1e14);
        _gas("gas.nativeZap.preview.cold", start_, 5_000_000);
        _cold();
        start_ = gasleft();
        assertEq(IStandardizedYield(address(vault)).deposit{value: 1e14}(address(this), address(0), 1e14, quote_), quote_);
        _gas("gas.nativeZap.execute.cold", start_, 11_900_000);
        uint256 shares_ = IERC20(address(vault)).balanceOf(address(this)) / 10;
        _cold();
        start_ = gasleft();
        quote_ = IStandardizedYield(address(vault)).previewRedeem(address(wrappedNative), shares_);
        _gas("gas.wrappedExit.preview.cold", start_, 5_000_000);
        _cold();
        start_ = gasleft();
        assertEq(IStandardizedYield(address(vault)).redeem(address(this), shares_, address(wrappedNative), quote_, false), quote_);
        _gas("gas.wrappedExit.execute.cold", start_, 11_900_000);
    }

    function test_GAS_ConditionalPairedExitAfterCrossingBudget() public {
        _denseBook(false);
        uint256 shares_ = IERC20(address(vault)).totalSupply() / 2;
        _cold();
        uint256 start_ = gasleft();
        (IVault.WithdrawalMode mode_, IVault.MaintenanceReason reason_) =
            vault.previewWithdrawalMode(shares_, true, address(0));
        _gas("gas.fallbackPair.mode.cold", start_, 5_000_000);
        assertEq(uint256(mode_), uint256(IVault.WithdrawalMode.CollectOnly));
        assertEq(uint256(reason_), uint256(IVault.MaintenanceReason.MaintenanceWorkLimit));
        _cold();
        start_ = gasleft();
        (uint256 amount0_, uint256 amount1_) = vault.previewRedeemPair(shares_);
        _gas("gas.fallbackPair.preview.cold", start_, 5_000_000);
        _cold();
        start_ = gasleft();
        vault.redeemPair(shares_, amount0_, amount1_, address(this), block.timestamp);
        _gas("gas.fallbackPair.execute.cold", start_, 11_900_000);
    }

    function test_GAS_Former512CandidatesRejectSingleExitBeforeExecution() public {
        _denseBook(true);
        uint256 supply_ = IERC20(address(vault)).totalSupply();
        uint256 shares_ = supply_ * 3 / 100;
        uint128 liquidity_ = vault.positionLiquidity();
        bytes memory error_ = abi.encodeWithSelector(IVault.QuoteTickCrossingsExceeded.selector, 13, 12);
        _cold();
        uint256 start_ = gasleft();
        vm.expectRevert(error_);
        vault.previewWithdrawalMode(shares_, false, address(token0));
        _gas("gas.rejectedCandidates.mode.cold", start_, 5_000_000);
        _cold();
        start_ = gasleft();
        vm.expectRevert(error_);ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(address(vault)))), IERC20(address(vault)), shares_, IERC20(address(token0))
        );
        _gas("gas.rejectedCandidates.preview.cold", start_, 5_000_000);
        _cold();
        start_ = gasleft();
        vm.expectRevert(error_);ExchangeInAmount.exchangeOut(IStandardExchangeIn(address(IStandardExchangeIn(address(vault)))), IERC20(address(vault)), shares_, IERC20(address(token0)),
            0, address(this), false, block.timestamp
        );
        _gas("gas.rejectedCandidates.execute.cold", start_, 11_900_000);
        assertEq(IERC20(address(vault)).totalSupply(), supply_);
        assertEq(IERC20(address(vault)).balanceOf(address(this)), supply_);
        assertEq(vault.positionLiquidity(), liquidity_);
    }

    /// @notice A28/A42/A61: maintenance fits but the complete sale exhausts its
    /// remaining budget; the fresh lower-work candidate remains usable when disabled.
    function test_GAS_FinalSaleExhaustionAfterMaintenanceAndDisabledFallback() public {
        key.tickSpacing = 1;
        pool.initialize(key, uint160(1) << 96);
        IPackage.PkgArgs memory args_ = _defaultArgs(key, address(token0), "sale work limit");
        args_.maxZapBps = 10000;
        vault = _deployVault(args_);
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e18, 1e18);
        for (int24 i_ = 1; i_ <= 6; ++i_) {
            poolActor.modifyLiquidity(key, ModifyLiquidityParams(-i_, 1, 1, bytes32(uint256(uint24(i_)))));
        }
        for (int24 i_ = 1; i_ <= 12; ++i_) {
            poolActor.modifyLiquidity(key, ModifyLiquidityParams(-1, i_, 1, bytes32(uint256(uint24(i_)) + 1000)));
        }
        _fund(address(this), 1e17, 0);
        vault.donate(address(token0), 1e17);
        uint256 supply_ = IERC20(address(vault)).totalSupply();
        uint256 shares_ = supply_ / 10;
        (IVault.WithdrawalMode pairMode_,) = vault.previewWithdrawalMode(shares_, true, address(0));
        assertEq(uint256(pairMode_), uint256(IVault.WithdrawalMode.FullCompound), "maintenance and removal fit");
        (IVault.WithdrawalMode saleMode_, IVault.MaintenanceReason reason_) =
            vault.previewWithdrawalMode(shares_, false, address(token0));
        assertEq(uint256(saleMode_), uint256(IVault.WithdrawalMode.CollectOnly));
        assertEq(uint256(reason_), uint256(IVault.MaintenanceReason.MaintenanceWorkLimit));(uint256 quote_,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(vault)), shares_, IERC20(address(token0))
        );
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        assertEq(IStandardizedYield(address(vault)).previewRedeem(address(token0), shares_), quote_);
        uint256 before_ = token0.balanceOf(address(this));
        assertEq(IStandardizedYield(address(vault)).redeem(address(this), shares_, address(token0), quote_, false), quote_);
        assertEq(token0.balanceOf(address(this)), before_ + quote_);
        assertEq(IERC20(address(vault)).totalSupply(), supply_ - shares_);
    }

    function _denseBook(bool bothDirections_) private {
        key.tickSpacing = 1;
        pool.initialize(key, uint160(1) << 96);
        IPackage.PkgArgs memory args_ = _defaultArgs(key, address(token0), "Gas dense pool");
        args_.maxZapBps = 10000;
        vault = _deployVault(args_);
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e18, 1e18);
        for (int24 i_ = 1; i_ <= 513; ++i_) {
            poolActor.modifyLiquidity(key, ModifyLiquidityParams(-i_, 1, 1, bytes32(uint256(uint24(i_)))));
        }
        if (bothDirections_) {
            for (int24 i_ = 1; i_ <= 510; ++i_) {
                poolActor.modifyLiquidity(key, ModifyLiquidityParams(-1, i_, 1, bytes32(uint256(uint24(i_)) + 1000)));
            }
        }
        _fund(address(this), 1e20, 0);
        vault.donate(address(token0), 1e20);
    }

    /// @notice Isolate cache serialization, swap and witness costs on the same real dense pool.
    function test_GAS_ProjectionMemoryProfile() public {
        _denseBook(true);
        Types.Inventory memory inventory_;
        (inventory_.booked.amount0, inventory_.booked.amount1) = vault.localReserves();
        Types.Config memory config_ = Types.Config(
            pool, key, address(indexedexManager), address(wrappedNative), address(token0),
            vault.tickLower(), vault.tickUpper(), vault.maxZapBps(), vault.maxZapTickMove(), 18
        );
        uint256 start_ = gasleft();
        Types.ProjectedState memory state_ =
            Projection.load(config_, inventory_, IERC20(address(vault)).totalSupply(), address(vault));
        emit log_named_uint("gas.profile.load", start_ - gasleft());
        start_ = gasleft();
        Types.ProjectedState memory initial_ = Projection.capture(state_);
        emit log_named_uint("gas.profile.captureInitial", start_ - gasleft());
        start_ = gasleft();
        (, Types.Failure memory failure_) =
            Projection.swap(state_, true, 1e20, TickMath.MIN_SQRT_PRICE + 1, Types.Phase.MaintenanceSwap);
        emit log_named_uint("gas.profile.swapUntilBudget", start_ - gasleft());
        assertEq(uint256(failure_.kind), uint256(Types.FailureKind.WorkLimit));
        assertEq(failure_.revertData, abi.encodeWithSelector(IVault.QuoteTickCrossingsExceeded.selector, 13, 12));
        assertEq(state_.tickCrossings, 12);
        start_ = gasleft();
        Types.ProjectedState memory final_ = Projection.capture(state_);
        emit log_named_uint("gas.profile.captureFinal", start_ - gasleft());
        start_ = gasleft();
        Projection.witness(initial_, state_);
        emit log_named_uint("gas.profile.initialWitness", start_ - gasleft());
        start_ = gasleft();
        Projection.witness(final_, state_);
        emit log_named_uint("gas.profile.finalWitness", start_ - gasleft());
    }

    /// @notice Isolate canonical settlement cost after the equivalent paired removal.
    function test_GAS_RealManager512CrossingSaleProfile() public {
        _denseBook(true);
        uint256 shares_ = IERC20(address(vault)).totalSupply() * 3 / 100;
        (, uint256 sale_) = vault.redeemPair(shares_, 0, 0, address(this), block.timestamp);
        _fund(address(poolActor), 0, sale_);
        vm.cool(address(poolActor));
        vm.cool(address(pool));
        vm.cool(address(token0));
        vm.cool(address(token1));
        uint256 start_ = gasleft();
        poolActor.swap(key, SwapParams(false, -int256(sale_), TickMath.MAX_SQRT_PRICE - 1));
        emit log_named_uint("gas.profile.realManagerSale", start_ - gasleft());
    }

    /// @notice The historical 512-step manager domain is deliberately excluded:
    /// the revised product rejects it before 1,020 canonical new storage writes.
    function test_GAS_RealManagerStorageWritesExceedEthereumTransactionCap() public {
        _denseBook(true);
        _fund(address(poolActor), 1e15, 1e15);
        poolActor.donate(key, 1e15, 1e15);
        uint256 shares_ = IERC20(address(vault)).totalSupply() * 3 / 100;
        vm.expectRevert(abi.encodeWithSelector(IVault.QuoteTickCrossingsExceeded.selector, 13, 12));
        vault.previewWithdrawalMode(shares_, false, address(token0));
        (, uint256 sale_) = vault.redeemPair(shares_, 0, 0, address(this), block.timestamp);
        for (int24 tick_ = 1; tick_ <= 510; ++tick_) {
            (,, uint256 growth0_, uint256 growth1_) = StateLibrary.getTickInfo(pool, key.toId(), tick_);
            assertEq(growth0_, 0);
            assertEq(growth1_, 0);
        }
        _fund(address(poolActor), 0, sale_);
        vm.cool(address(poolActor));
        vm.cool(address(pool));
        vm.cool(address(token0));
        vm.cool(address(token1));
        uint256 start_ = gasleft();
        poolActor.swap(key, SwapParams(false, -int256(sale_), TickMath.MAX_SQRT_PRICE - 1));
        uint256 used_ = start_ - gasleft();
        emit log_named_uint("gas.profile.realManagerBothFeeCurrencies", used_);
        for (int24 tick_ = 1; tick_ <= 510; ++tick_) {
            (,, uint256 growth0_, uint256 growth1_) = StateLibrary.getTickInfo(pool, key.toId(), tick_);
            assertGt(growth0_, 0);
            assertGt(growth1_, 0);
        }
        uint256 storageLowerBound_ = 510 * 2 * 20_000;
        assertGt(storageLowerBound_, 16_777_216, "canonical writes alone exceed the transaction cap");
        assertGe(used_, storageLowerBound_);
    }

    function _gas(string memory label_, uint256 start_, uint256 ceiling_) private {
        uint256 used_ = start_ - gasleft();
        emit log_named_uint(label_, used_);
        assertLe(used_, ceiling_, "approved engineering gas ceiling");
    }

    function _cold() private {
        address[] memory facets_ = pairTokenPackage.facetAddresses();
        for (uint256 i_ = 0; i_ < facets_.length; ++i_) vm.cool(facets_[i_]);
        for (uint256 i_ = 0; i_ < 6; ++i_) vm.cool(pkgInit.linkedLibraries[i_]);
        vm.cool(address(vault)); vm.cool(address(pool)); vm.cool(address(indexedexManager));
        if (address(token0) != address(0)) vm.cool(address(token0));
        vm.cool(address(token1)); vm.cool(address(wrappedNative));
    }

    function _size(address component_) private view {
        assertGt(component_.code.length, 0);
        assertLe(component_.code.length, 24576, "normal runtime limit");
    }

    function _direct(address component_, bytes memory payload_, bytes memory expected_) private {
        (bool success_, bytes memory result_) = component_.call(payload_);
        assertFalse(success_);
        assertEq(result_, expected_);
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultFeasibilityTest[]
