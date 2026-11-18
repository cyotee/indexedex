// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Events} from "@crane/contracts/interfaces/IERC20Events.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {Vm} from "forge-std/Vm.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as V3Vault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {IStandardExchangeRateProvider} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProvider.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as WeightedHook} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as HookPackage} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookCapture as Capture} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_FactoryService as HookFactory} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Weighted} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {MigrationSnapshotConsumer, MigrationWeightedPricingFixture} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {IUniswapV4DetfMigrationWeightedPricingV3 as PricingV3,
    IUniswapV4DetfMigrationWeightedPricingAllocationV3 as PricingAllocationV3} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricingV3.sol";

/// @notice Observed Raw/RawRate books compared with independent production hook calls.
/// @dev R2's output provider is an SE-share-derived policy rate, not the parent DETF economic price.
contract MigrationRawWeightedPricingTest is TestBase_UniswapV4DetfMigration {
    MigrationSnapshotConsumer internal consumer;
    address internal auxiliary;
    uint256 internal seedDetf;
    bytes internal parentInventory;

    /// @notice Obtain native9 DETF only by funding, issuing, maturing, claiming and exiting real sDETF.
    function setUp() public override {
        super.setUp();
        _fundAndCapture();
        uint256 credit_ = _configure(address(this), 1 ether, bytes32("raw pricing principal"));
        uint256 id_ = _issue(address(this));
        vm.warp(bonds.positionOf(id_).startTimestamp + bonds.positionOf(id_).vestingDuration + 1);
        uint256 receiptBefore_ = receipt.balanceOf(address(this));
        uint256 principalPaid_ = bonds.claimPrincipal(id_, address(this));
        assertGt(principalPaid_, 0);
        assertEq(principalPaid_, credit_);
        assertEq(receipt.balanceOf(address(this)) - receiptBefore_, principalPaid_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(address(this));
        receipt.exchangeIn(
            IERC20(address(receipt)), principalPaid_, IERC20(detf), principalPaid_,
            address(this), false, block.timestamp
        );
        assertEq(IERC20(detf).balanceOf(address(this)) - detfBefore_, principalPaid_);
        assertEq(IERC20Metadata(detf).decimals(), 9);
        seedDetf = principalPaid_ / 8;
        assertGt(seedDetf, 0);
        assertLt(seedDetf, principalPaid_);

        address[] memory underlying_ = IBasicVault(se0).vaultTokens();
        assertEq(underlying_.length, 2);
        assertTrue(underlying_[0] == pairA || underlying_[1] == pairA);
        auxiliary = underlying_[0] == pairA ? underlying_[1] : underlying_[0];
        assertTrue(auxiliary != address(0) && auxiliary != pairA && auxiliary != pairB && auxiliary != detf);
        consumer = MigrationSnapshotConsumer(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(
                create3Factory, "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotConsumer"
            ),
            abi.encode(detf, pairA, pairB), bytes32("raw pricing consumer")
        ));
        parentInventory = _parentInventory();
    }

    /// @notice Both raw contributions, independent user floors, and zero-seigniorage control at the reported fee.
    function test_RawObservedHookParity() public {
        address hook_ = _comparison(0);
        Pricing.InputsV3 memory inputs_ = _install(hook_, 5e16);
        _assertBoth(hook_, inputs_, 1 ether + 123, 2 ether + 789);
        uint256 actualFee_ = _setFee(hook_, 0);
        emit log_named_uint("stored zero fee reads back as the vault-type default", actualFee_);
        inputs_ = _install(hook_, 0);
        assertEq(inputs_.swapFeeWad, actualFee_);
        _assertBoth(hook_, inputs_, 1 ether + 123, 2 ether + 789);
        assertEq(_parentInventory(), parentInventory);
    }

    /// @notice Non-unit production input providers map both native18 raw inflows exactly.
    function test_RawRateInputObservedHookParity() public {
        address hook_ = _comparison(1);
        Pricing.InputsV3 memory inputs_ = _install(hook_, 5e16);
        _assertBoth(hook_, inputs_, 1 ether + 123, 2 ether + 789);
        assertEq(uint256(inputs_.legs[inputs_.detfIndex].mode), uint256(Pricing.LegMode.Raw));
        assertEq(_parentInventory(), parentInventory);
    }

    /// @notice The explicit se0/pairA output policy provider exercises admitted native9 RawRate output.
    function test_RawRateOutputObservedHookParity() public {
        address hook_ = _comparison(2);
        Pricing.InputsV3 memory inputs_ = _install(hook_, 5e16);
        address provider_ = WeightedHook(hook_).rateProvider(inputs_.detfIndex);
        IStandardExchangeRateProvider output_ = IStandardExchangeRateProvider(provider_);
        assertEq(address(output_.reserveVault()), se0);
        assertEq(address(output_.rateTarget()), pairA);
        assertEq(inputs_.legs[inputs_.detfIndex].rate, output_.getRate());
        assertEq(provider_, WeightedHook(hook_).rateProvider(inputs_.ethIndex));
        emit log("R2 output: SE-share-derived se0/pairA policy rate; not parent DETF economic price");
        _assertBoth(hook_, inputs_, 1 ether + 123, 2 ether + 789);
        assertEq(_parentInventory(), parentInventory);
    }

    /// @notice Find native9 minimum, max-in and output-reserve endpoints using the live hook alone.
    function test_RawModelsObservedDomainBoundaries() public {
        for (uint256 model_; model_ < 3; ++model_) {
            address hook_ = _comparison(model_);
            Pricing.InputsV3 memory inputs_ = _install(hook_, 5e16);
            for (uint256 leg_; leg_ < 2; ++leg_) {
                address input_ = leg_ == 0 ? pairA : pairB;
                uint256 first_ = _firstLiveSuccess(hook_, input_, inputs_.seigniorage);
                Pricing.Result memory floor_ = _assertContribution(hook_, inputs_, input_, first_);
                assertEq(floor_.gross, 1, "first successful native9 output is one atomic unit");
                assertEq(floor_.user, 0, "user floor applied after gross native9 floor");
                _reject(hook_, inputs_, input_, first_ - 1, Weighted.ZeroAmount.selector);
                _lastLiveSuccess(hook_, inputs_, input_, Weighted.MaxInRatio.selector);
            }
            if (model_ == 2) {
                address provider_ = WeightedHook(hook_).rateProvider(inputs_.detfIndex);
                uint256 beforeRate_ = IStandardExchangeRateProvider(provider_).getRate();
                _donateBacking(2000 ether);
                uint256 afterRate_ = IStandardExchangeRateProvider(provider_).getRate();
                assertGt(afterRate_, beforeRate_);
                emit log_named_uint("output boundary rate before", beforeRate_);
                emit log_named_uint("output boundary rate after", afterRate_);
                inputs_ = _install(hook_, 5e16);
                _lastLiveSuccess(hook_, inputs_, pairA, Weighted.WouldZeroReserve.selector);
                _lastLiveSuccess(hook_, inputs_, pairB, Weighted.WouldZeroReserve.selector);
            }
        }
        assertEq(_parentInventory(), parentInventory);
    }

    /// @notice Real swaps/backing changes leave loaded evaluation frozen until explicit owner replacement.
    function test_RawModelsFrozenBookAndExplicitReplacement() public {
        for (uint256 model_; model_ < 3; ++model_) {
            address hook_ = _comparison(model_);
            Pricing.InputsV3 memory inputs_ = _install(hook_, 5e16);
            _assertBoth(hook_, inputs_, 1 ether, 2 ether);
            bytes memory frozen_ = consumer.snapshotBytes();
            bytes memory parentBook_ = abi.encode(PricingV3(address(migration)).migrationWeightedPricingV3());
            uint256 credit_ = migration.previewOriginalCredit(1 ether, 2 ether);
            (uint256 liveBefore_,) = IStandardExchangeIn(hook_).previewExchangeIn(
                IERC20(pairA), 1.05 ether, IERC20(detf)
            );
            if (model_ == 2) {
                address provider_ = WeightedHook(hook_).rateProvider(inputs_.detfIndex);
                uint256 rateBefore_ = IStandardExchangeRateProvider(provider_).getRate();
                _donateBacking(10 ether);
                assertNotEq(IStandardExchangeRateProvider(provider_).getRate(), rateBefore_);
            } else {
                IERC20(pairA).approve(hook_, 1 ether);
                uint256 before_ = IERC20(detf).balanceOf(address(this));
                uint256 paid_ = WeightedHook(hook_).ownerSwapExactIn(pairA, detf, 1 ether, 1, block.timestamp);
                assertEq(IERC20(detf).balanceOf(address(this)) - before_, paid_);
                assertGt(paid_, 0);
            }
            (uint256 liveAfter_,) = IStandardExchangeIn(hook_).previewExchangeIn(
                IERC20(pairA), 1.05 ether, IERC20(detf)
            );
            assertNotEq(liveAfter_, liveBefore_, "genuine live change is effective");
            assertEq(consumer.snapshotBytes(), frozen_);
            assertEq(abi.encode(PricingV3(address(migration)).migrationWeightedPricingV3()), parentBook_);
            assertEq(consumer.evaluateOriginals(1 ether, 2 ether), credit_);
            assertEq(migration.previewOriginalCredit(1 ether, 2 ether), credit_);
            inputs_ = _install(hook_, 5e16);
            assertNotEq(consumer.snapshotBytes(), frozen_);
            _assertBoth(hook_, inputs_, 1 ether, 2 ether);
            assertNotEq(migration.previewOriginalCredit(1 ether, 2 ether), credit_);
        }
        assertEq(_parentInventory(), parentInventory);
    }

    /// @notice A deliberate manual fee adjustment changes credit while the entire live captured book stays fixed.
    function test_RawRateManualAdjustmentWithoutLiveMutation() public {
        address hook_ = _comparison(2);
        Pricing.InputsV3 memory inputs_ = _install(hook_, 5e16);
        _assertBoth(hook_, inputs_, 1 ether, 2 ether);
        bytes memory liveBook_ = abi.encode(Capture(hook_).captureWeightedMintBook());
        uint256 before_ = migration.previewOriginalCredit(1 ether, 2 ether);
        (uint256 grossBefore_,) = IStandardExchangeIn(hook_).previewExchangeIn(
            IERC20(pairA), 1.05 ether, IERC20(detf)
        );
        inputs_.swapFeeWad = 1e17;
        _setInputs(inputs_);
        assertNotEq(migration.previewOriginalCredit(1 ether, 2 ether), before_);
        assertEq(migration.previewOriginalCredit(1 ether, 2 ether), consumer.evaluateOriginals(1 ether, 2 ether));
        assertEq(abi.encode(Capture(hook_).captureWeightedMintBook()), liveBook_);
        (uint256 grossAfter_,) = IStandardExchangeIn(hook_).previewExchangeIn(
            IERC20(pairA), 1.05 ether, IERC20(detf)
        );
        assertEq(grossAfter_, grossBefore_);
        emit log_named_uint("observed credit", before_);
        emit log_named_uint("manually adjusted credit", migration.previewOriginalCredit(1 ether, 2 ether));
        inputs_ = _install(hook_, 5e16);
        _assertBoth(hook_, inputs_, 1 ether, 2 ether);
        assertEq(migration.previewOriginalCredit(1 ether, 2 ether), before_);
        assertEq(_parentInventory(), parentInventory);
    }

    function _comparison(uint256 model_) private returns (address hook_) {
        address[] memory tokens_ = new address[](4);
        tokens_[0] = pairA; tokens_[1] = pairB; tokens_[2] = detf; tokens_[3] = auxiliary;
        _sortInPlace(tokens_);
        HookPackage.PkgArgs memory args_;
        args_.poolManager = address(pm);
        args_.feeOracle = address(indexedexManager);
        args_.n = 4;
        args_.tokens = tokens_;
        args_.weights = new uint256[](4);
        args_.standardExchanges = new address[](4);
        args_.rateProviders = new address[](4);
        args_.ownerOnlyLiquidity = true;
        args_.owner = address(this);
        for (uint256 i_; i_ < 4; ++i_) {
            address token_ = tokens_[i_];
            args_.weights[i_] = token_ == pairA ? 3e17 : token_ == pairB ? 2e17 : token_ == detf ? 4e17 : 1e17;
            if (token_ == auxiliary) args_.standardExchanges[i_] = se0;
            else if (model_ != 0 && (token_ != detf || model_ == 2)) {
                args_.rateProviders[i_] = RateProviderFixtureLib.providerFor(
                    create3Factory, diamondPackageFactory, token_ == pairB ? se1 : se0, token_ == pairB ? pairB : pairA
                );
            }
        }
        args_.rateProviders = RateProviderFixtureLib.fillMissing(
            create3Factory, diamondPackageFactory, tokens_, args_.standardExchanges, args_.rateProviders
        );
        args_.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(tokens_);
        args_.seDecimals = HookPkgArgsDecimalsLib.seDecimals(args_.standardExchanges);
        uint256 nonce_ = HookFactory.findMineNonce(hookFactory, weightedHookPkg, args_);
        hook_ = weightedHookPkg.deployVault(args_, nonce_);
        assertNotEq(hook_, reserveHook);
        assertEq(IVaultRegistryDisableQuery(address(indexedexManager)).packageOfVault(hook_), address(weightedHookPkg));
        IUniswapV4HookStagedPairInit init_ = IUniswapV4HookStagedPairInit(hook_);
        for (uint256 i_; i_ < 4; ++i_) {
            for (uint256 j_ = i_ + 1; j_ < 4; ++j_) init_.deployPair(tokens_[i_], tokens_[j_]);
        }
        assertTrue(init_.finalizeInitialization());
        assertEq(WeightedHook(hook_).pairDoorCount(), 6);
        _seed(hook_, tokens_);
        _setFee(hook_, 3e15);
        emit log_named_uint("R variant", model_);
        emit log_named_address("comparison hook", hook_);
        emit log_named_bytes("sorted token/weight/SE/provider/decimal bindings", abi.encode(args_));
        assertEq(_parentInventory(), parentInventory);
    }

    function _seed(address hook_, address[] memory tokens_) private {
        uint256 auxiliaryBefore_ = IERC20(auxiliary).balanceOf(address(this));
        uint256 sharesBefore_ = IERC20(se0).balanceOf(address(this));
        IERC20(auxiliary).approve(se0, 10 ether);
        (uint256 shares_, uint256 refund_) = IStandardExchangeIn(se0).exchangeIn(
            IERC20(auxiliary), 10 ether, IERC20(se0), 1, address(this), false, block.timestamp
        );
        assertGt(shares_, 0);
        assertEq(IERC20(se0).balanceOf(address(this)) - sharesBefore_, shares_);
        assertEq(auxiliaryBefore_ - IERC20(auxiliary).balanceOf(address(this)), 10 ether - refund_);
        uint256[] memory amounts_ = new uint256[](4);
        uint256[] memory before_ = new uint256[](4);
        bool[] memory flags_ = new bool[](4);
        for (uint256 i_; i_ < 4; ++i_) {
            flags_[i_] = tokens_[i_] == auxiliary;
            amounts_[i_] = flags_[i_] ? shares_ : tokens_[i_] == detf ? seedDetf : 100 ether;
            IERC20 currency_ = IERC20(flags_[i_] ? se0 : tokens_[i_]);
            before_[i_] = currency_.balanceOf(address(this));
            currency_.approve(hook_, amounts_[i_]);
        }
        uint256 supplyBefore_ = IERC20(se0).totalSupply();
        assertEq(IERC20(auxiliary).balanceOf(hook_), 0);
        vm.recordLogs();
        (uint256 lp_, uint256[] memory used_) = WeightedHook(hook_).joinProportionalFlexible(
            amounts_, flags_, address(this), 1, block.timestamp
        );
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 redeemed_;
        uint256 received_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            Vm.Log memory entry_ = logs_[i_];
            if (entry_.topics.length != 3 || entry_.topics[0] != IERC20Events.Transfer.selector) continue;
            if (entry_.emitter == se0 && entry_.topics[2] == bytes32(0)) {
                redeemed_ += abi.decode(entry_.data, (uint256));
            }
            if (
                entry_.emitter == auxiliary
                    && entry_.topics[1] == bytes32(uint256(uint160(se0)))
                    && entry_.topics[2] == bytes32(uint256(uint160(hook_)))
            ) {
                received_ += abi.decode(entry_.data, (uint256));
            }
        }
        assertGt(redeemed_, 0);
        assertEq(supplyBefore_ - IERC20(se0).totalSupply(), redeemed_);
        assertGt(received_, 0);
        assertEq(IERC20(auxiliary).balanceOf(hook_), received_);
        assertGt(lp_, 0);
        assertEq(IERC20(hook_).balanceOf(address(this)), lp_);
        for (uint256 i_; i_ < 4; ++i_) {
            IERC20 currency_ = IERC20(flags_[i_] ? se0 : tokens_[i_]);
            assertGt(used_[i_], 0);
            assertLe(used_[i_], amounts_[i_]);
            assertEq(before_[i_] - currency_.balanceOf(address(this)), used_[i_]);
            if (flags_[i_]) {
                uint256 retained_ = WeightedHook(hook_).seBalance(i_);
                assertEq(currency_.balanceOf(hook_), retained_);
                assertEq(used_[i_], retained_ + redeemed_, "supplied shares retained or genuinely redeemed");
                assertEq(Capture(hook_).captureWeightedMintBook().legs[i_].rawReserve, received_);
                emit log_named_uint("auxiliary retained SE shares", retained_);
            } else {
                assertEq(currency_.balanceOf(hook_), used_[i_]);
                assertEq(WeightedHook(hook_).nativeReserve(i_), used_[i_]);
            }
            emit log_named_uint("join used", used_[i_]);
            emit log_named_uint("join unspent/refunded", amounts_[i_] - used_[i_]);
        }
        emit log_named_uint("auxiliary deposit shares", shares_);
        emit log_named_uint("auxiliary deposit refund", refund_);
        emit log_named_uint("auxiliary redeemed SE shares", redeemed_);
        emit log_named_uint("auxiliary received raw tokens", received_);
        emit log_named_uint("comparison LP", lp_);
    }

    function _setFee(address hook_, uint256 fee_) private returns (uint256 actualFee_) {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook_, fee_);
        actualFee_ = WeightedHook(hook_).dexSwapFee();
        if (fee_ != 0) assertEq(actualFee_, fee_);
    }

    /// @dev Only authorized maintenance makes input part of the current V3 share claim.
    function _donateBacking(uint256 amount_) private {
        address authority_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(authority_);
        V3Vault(se0).setOperatorFor(V3Vault.donate.selector, address(this), true);
        IERC20(pairA).approve(se0, amount_);
        V3Vault(se0).donate(pairA, amount_, false);
        vm.prank(authority_);
        V3Vault(se0).setOperatorFor(V3Vault.donate.selector, address(this), false);
    }

    function _install(address hook_, uint256 seigniorage_) private returns (Pricing.InputsV3 memory inputs_) {
        inputs_ = MigrationWeightedPricingFixture.observedHook(detf, hook_, seigniorage_, pairA, pairB, _v3PricingBindings());
        Capture.Book memory captured_ = Capture(hook_).captureWeightedMintBook();
        for (uint256 i_; i_ < inputs_.legs.length; ++i_) {
            Pricing.LegV3 memory leg_ = inputs_.legs[i_];
            assertEq(leg_.standardExchange, captured_.legs[i_].standardExchange);
            assertEq(captured_.legs[i_].provider, WeightedHook(hook_).rateProvider(i_));
            assertEq(leg_.rawReserve, captured_.legs[i_].rawReserve);
            assertEq(leg_.seReserve, captured_.legs[i_].seReserve);
            if (leg_.token == auxiliary) {
                assertEq(leg_.standardExchange, se0);
                assertGt(leg_.seReserve, 0);
            } else {
                assertEq(leg_.standardExchange, address(0));
                assertGt(leg_.rawReserve, 0);
                assertEq(leg_.seReserve, 0);
                assertEq(uint256(leg_.mode), uint256(captured_.legs[i_].provider == address(0)
                    ? Pricing.LegMode.Raw : Pricing.LegMode.RawRate));
            }
            if (leg_.mode == Pricing.LegMode.RawRate) {
                assertGt(leg_.rate, 0);
                assertNotEq(leg_.rate, 1e18);
                assertEq(leg_.rate, IStandardExchangeRateProvider(captured_.legs[i_].provider).getRate());
            }
        }
        assertEq(inputs_.legs[inputs_.ethIndex].weight, 3e17);
        assertEq(inputs_.legs[inputs_.dtfIndex].weight, 2e17);
        assertEq(inputs_.legs[inputs_.detfIndex].weight, 4e17);
        assertEq(inputs_.legs[inputs_.detfIndex].ratedScale, 1e27);
        _setInputs(inputs_);
        emit log_named_bytes("captured book and manual inputs", abi.encode(captured_, inputs_));
    }

    function _setInputs(Pricing.InputsV3 memory inputs_) private {
        bytes32 id_ = consumer.set(inputs_);
        vm.prank(migration.owner());
        assertEq(PricingAllocationV3(address(allocation)).setMigrationWeightedPricingV3(inputs_), id_);
        assertEq(abi.encode(PricingV3(address(migration)).migrationWeightedPricingV3()), consumer.snapshotBytes());
    }

    function _assertBoth(address hook_, Pricing.InputsV3 memory inputs_, uint256 eth_, uint256 dtf_) private {
        bytes memory before_ = abi.encode(Capture(hook_).captureWeightedMintBook());
        Pricing.Result memory a_ = _assertContribution(hook_, inputs_, pairA, eth_);
        Pricing.Result memory b_ = _assertContribution(hook_, inputs_, pairB, dtf_);
        assertGt(a_.user, 0);
        assertGt(b_.user, 0);
        assertEq(migration.previewOriginalCredit(eth_, dtf_), a_.user + b_.user);
        assertEq(consumer.evaluateOriginals(eth_, dtf_), a_.user + b_.user);
        assertEq(migration.previewOriginalCredit(eth_, 0), a_.user);
        assertEq(migration.previewOriginalCredit(0, dtf_), b_.user);
        assertEq(migration.previewOriginalCredit(0, 0), 0);
        Pricing.Result memory empty_;
        assertEq(abi.encode(consumer.evaluate(address(0), 0)), abi.encode(empty_));
        assertEq(abi.encode(consumer.evaluate(pairB, 0)), abi.encode(empty_));
        assertEq(abi.encode(Capture(hook_).captureWeightedMintBook()), before_, "both originals use unchanged book");
    }

    function _assertContribution(address hook_, Pricing.InputsV3 memory inputs_, address input_, uint256 amount_)
        private returns (Pricing.Result memory actual_)
    {
        Pricing.LegV3 memory leg_ = inputs_.legs[input_ == pairA ? inputs_.ethIndex : inputs_.dtfIndex];
        uint256 boosted_ = Math.mulDiv(amount_, 1e18 + inputs_.seigniorage, 1e18);
        (uint256 gross_, uint256 refund_) = IStandardExchangeIn(hook_).previewExchangeIn(
            IERC20(input_), boosted_, IERC20(detf)
        );
        assertEq(refund_, 0, "successful raw quote never refunds input");
        uint256 net_ = boosted_ - Math.mulDiv(boosted_, inputs_.swapFeeWad, 1e18);
        uint256 rated_ = leg_.mode == Pricing.LegMode.Raw ? net_ : Math.mulDiv(net_, leg_.rate, 1e18);
        rated_ = Math.mulDiv(rated_, leg_.ratedScale, 1e18);
        uint256 user_ = Math.mulDiv(gross_, 1e18 - inputs_.seigniorage, 1e18);
        actual_ = consumer.evaluate(input_ == pairA ? address(0) : pairB, amount_);
        emit log_named_address("input", input_);
        emit log_named_bytes("amount/boosted/fee/net/rate/rated/gross/user and evaluator",
            abi.encode(amount_, boosted_, boosted_ - net_, net_, leg_.rate, rated_, gross_, user_, actual_));
        emit log_named_uint("live gross native9", gross_);
        emit log_named_uint("live user native9", user_);
        assertEq(actual_.pairEquivalent, amount_);
        assertEq(actual_.boosted, boosted_);
        assertEq(actual_.net, net_);
        assertEq(actual_.ratedInflow, rated_);
        assertEq(actual_.gross, gross_, "gross oracle is external production hook call");
        assertEq(actual_.user, user_);
        assertGt(gross_, 0);
        assertLt(gross_, inputs_.legs[inputs_.detfIndex].rawReserve);
    }

    function _live(address hook_, address input_, uint256 amount_, uint256 p_)
        private view returns (bool ok_, bytes memory data_)
    {
        return hook_.staticcall(abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (IERC20(input_), Math.mulDiv(amount_, 1e18 + p_, 1e18), IERC20(detf))));
    }

    function _firstLiveSuccess(address hook_, address input_, uint256 p_) private returns (uint256 hi_) {
        uint256 lo_ = 1;
        hi_ = 1 ether;
        (bool ok_, bytes memory data_) = _live(hook_, input_, lo_, p_);
        assertFalse(ok_);
        assertEq(data_, abi.encodeWithSelector(Weighted.ZeroAmount.selector));
        (ok_,) = _live(hook_, input_, hi_, p_);
        assertTrue(ok_);
        while (hi_ - lo_ > 1) {
            uint256 mid_ = lo_ + (hi_ - lo_) / 2;
            (ok_, data_) = _live(hook_, input_, mid_, p_);
            if (ok_) hi_ = mid_;
            else {
                assertEq(data_, abi.encodeWithSelector(Weighted.ZeroAmount.selector));
                lo_ = mid_;
            }
        }
        emit log_named_uint("first live native9 success original", hi_);
    }

    function _lastLiveSuccess(address hook_, Pricing.InputsV3 memory inputs_, address input_, bytes4 expected_) private {
        uint256 lo_ = 1 ether;
        uint256 hi_ = inputs_.legs[input_ == pairA ? inputs_.ethIndex : inputs_.dtfIndex].rawReserve * 2;
        (bool ok_,) = _live(hook_, input_, lo_, inputs_.seigniorage);
        assertTrue(ok_);
        (ok_,) = _live(hook_, input_, hi_, inputs_.seigniorage);
        assertFalse(ok_);
        while (hi_ - lo_ > 1) {
            uint256 mid_ = lo_ + (hi_ - lo_) / 2;
            bytes memory reason_;
            (ok_, reason_) = _live(hook_, input_, mid_, inputs_.seigniorage);
            if (ok_) lo_ = mid_;
            else {
                assertTrue(
                    keccak256(reason_) == keccak256(abi.encodeWithSelector(expected_))
                    || keccak256(reason_) == keccak256(abi.encodeWithSelector(Weighted.MaxInRatio.selector)),
                    "search only crosses genuine max-in or output-reserve guards"
                );
                hi_ = mid_;
            }
        }
        _assertContribution(hook_, inputs_, input_, lo_);
        _reject(hook_, inputs_, input_, hi_, expected_);
        emit log_named_uint("last live success original", lo_);
        emit log_named_uint("first live rejection original", hi_);
    }

    function _reject(address hook_, Pricing.InputsV3 memory inputs_, address input_, uint256 amount_, bytes4 expected_)
        private
    {
        (bool liveOk_, bytes memory liveReason_) = _live(hook_, input_, amount_, inputs_.seigniorage);
        (bool frozenOk_, bytes memory frozenReason_) = address(consumer).staticcall(
            abi.encodeCall(consumer.evaluate, (input_ == pairA ? address(0) : pairB, amount_))
        );
        (bool parentOk_, bytes memory parentReason_) = detf.staticcall(
            abi.encodeCall(migration.previewOriginalCredit, (input_ == pairA ? amount_ : 0, input_ == pairB ? amount_ : 0))
        );
        assertFalse(liveOk_);
        assertFalse(frozenOk_);
        assertFalse(parentOk_);
        assertEq(liveReason_, abi.encodeWithSelector(expected_));
        assertEq(frozenReason_, liveReason_, "exact live/evaluator rejection bytes");
        assertEq(parentReason_, liveReason_, "exact live/parent rejection bytes");
        emit log_named_bytes("live and loaded rejection", liveReason_);
    }

    function _parentInventory() private view returns (bytes memory) {
        return abi.encode(
            detfInfo.hook(), WeightedHook(reserveHook).nativeReserves(),
            IERC20(reserveHook).totalSupply(), IERC20(reserveHook).balanceOf(detf),
            IERC20(detf).balanceOf(reserveHook), IERC20(pairA).balanceOf(reserveHook),
            IERC20(pairB).balanceOf(reserveHook), IERC20(se0).balanceOf(reserveHook),
            IERC20(se1).balanceOf(reserveHook)
        );
    }
}
