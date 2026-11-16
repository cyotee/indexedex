// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {MigrationSnapshotMathExposure} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Weighted} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";

/// @notice Manual book lifecycle exercised through the actual registry-deployed migration proxy.
contract MigrationWeightedPricingTest is TestBase_UniswapV4DetfMigration {
    address constant NFT = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;

    function _rawInputs() private view returns (Pricing.Inputs memory a_) {
        a_.swapFeeWad = 3e15;
        a_.seigniorage = 5e16;
        a_.dtfIndex = 1;
        a_.detfIndex = 2;
        a_.legs = new Pricing.Leg[](3);
        a_.legs[0].token = pairA;
        a_.legs[1].token = pairB;
        a_.legs[2].token = detf;
        for (uint256 i_; i_ < 3; ++i_) {
            a_.legs[i_].weight = i_ == 2 ? 4e17 : 3e17;
            a_.legs[i_].invScale = i_ == 2 ? 1e27 : 1e18;
            a_.legs[i_].ratedScale = a_.legs[i_].invScale;
            a_.legs[i_].rawReserve = i_ == 2 ? 1000e9 : 1000 ether;
        }
    }

    function _set(Pricing.Inputs memory a_) private returns (bytes32) {
        vm.prank(migration.owner());
        pricingId = allocation.setMigrationWeightedPricing(a_);
        return pricingId;
    }

    function _math() private returns (MigrationSnapshotMathExposure) {
        return MigrationSnapshotMathExposure(create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory,
                "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotMathExposure"), bytes32("manual math")
        ));
    }

    /// @notice Empty storage rejects even zero previews and empty batches, without adding a funding gate.
    function test_UnsetPricing_GetterPreviewAndAllLoaders() public {
        vm.expectRevert(Pricing.MigrationWeightedPricingNotSet.selector);
        migration.migrationWeightedPricing();
        vm.expectRevert(Pricing.MigrationWeightedPricingNotSet.selector);
        migration.previewOriginalCredit(0, 0);
        bytes4[] memory writers_ = _writers();
        for (uint256 i_ = 2; i_ < 14; ++i_) {
            vm.prank(migrationOwner);
            (bool ok_, bytes memory reason_) = detf.call(abi.encodeWithSelector(writers_[i_], new uint256[](0), bytes32(0)));
            assertFalse(ok_);
            assertEq(reason_, abi.encodeWithSelector(Pricing.MigrationWeightedPricingNotSet.selector));
        }
        _set(_rawInputs());
        assertEq(IERC20(detf).totalSupply(), 0, "setting does not fund or issue");
    }

    /// @notice Complete domain encoding, replaceability and idempotence use no revision counter.
    function test_ManualBook_AThenBThenIdenticalB() public {
        Pricing.Inputs memory a_ = _rawInputs();
        Pricing.Book memory expected_ = Pricing.Book(2, block.chainid, detf, pairA, pairB, bytes32(0), a_);
        bytes32 expectedId_ = keccak256(abi.encode("IndexedEx.manual-weighted-original-credit", expected_));
        vm.expectEmit(true, false, false, true, detf);
        emit Pricing.MigrationWeightedPricingSet(expectedId_);
        assertEq(_set(a_), expectedId_);
        expected_.id = expectedId_;
        assertEq(abi.encode(migration.migrationWeightedPricing()), abi.encode(expected_));
        uint256 before_ = migration.previewOriginalCredit(1 ether, 1 ether);
        a_.swapFeeWad = 1e17;
        bytes32 b_ = _set(a_);
        assertNotEq(b_, expectedId_);
        assertNotEq(migration.previewOriginalCredit(1 ether, 1 ether), before_);
        assertEq(_set(a_), b_);
        assertEq(IERC20(detf).totalSupply(), 0);
    }

    /// @notice Only the accepted current owner can set; pending and former owners have no authority.
    function test_UnauthorizedPricing_CurrentPendingFormerOwnerAndRollback() public {
        Pricing.Inputs memory a_ = _rawInputs();
        _set(a_);
        bytes memory before_ = abi.encode(migration.migrationWeightedPricing());
        address next_ = makeAddr("pricing owner");
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(next_);
        address[2] memory callers_ = [address(this), next_];
        for (uint256 i_; i_ < 2; ++i_) {
            vm.prank(callers_[i_]);
            vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, callers_[i_]));
            allocation.setMigrationWeightedPricing(a_);
            assertEq(abi.encode(migration.migrationWeightedPricing()), before_);
        }
        vm.prank(next_); migration.acceptOwnershipTransfer();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, migrationOwner));
        allocation.setMigrationWeightedPricing(a_);
        a_.swapFeeWad = 1e17;
        _set(a_);
        assertEq(migration.migrationWeightedPricing().inputs.swapFeeWad, 1e17);
    }

    /// @notice Every structurally invalid replacement leaves the complete previous book intact.
    function test_InvalidManual_PricingRollback_AllStructuralFields() public {
        _set(_rawInputs());
        bytes memory before_ = abi.encode(migration.migrationWeightedPricing());
        for (uint256 i_; i_ < 29; ++i_) {
            Pricing.Inputs memory a_ = _rawInputs();
            if (i_ == 0) a_.legs = new Pricing.Leg[](2);
            else if (i_ == 1) a_.legs[0].token = address(0);
            else if (i_ == 2) a_.legs[1].token = pairA;
            else if (i_ == 3) a_.ethIndex = 3;
            else if (i_ == 4) a_.dtfIndex = 0;
            else if (i_ == 5) a_.legs[0].token = address(0xBAD);
            else if (i_ == 6) a_.swapFeeWad = 1e18;
            else if (i_ == 7) a_.seigniorage = 1e18 + 1;
            else if (i_ == 8) a_.legs[0].weight = 1e16 - 1;
            else if (i_ == 9) a_.legs[0].weight += 1;
            else if (i_ == 10) a_.legs[0].invScale = 11;
            else if (i_ == 11) a_.legs[0].ratedScale = 1e17;
            else if (i_ == 12) a_.legs[2].ratedScale = 1e18;
            else if (i_ == 13) a_.legs[0].standardExchange = se0;
            else if (i_ == 14) a_.legs[0].seReserve = 1;
            else if (i_ == 15) a_.legs[0].rate = 1;
            else if (i_ == 16) a_.legs[0].mode = Pricing.LegMode.RawRate;
            else if (i_ == 17) a_.legs[0].deposit.model = Frozen.Model.UniswapV3PairDeposit;
            else if (i_ == 18) a_.legs[0].deposit.exchange = se0;
            else if (i_ == 19) a_.legs[0].deposit.request.tokenIn = pairA;
            else if (i_ == 20) a_.legs[0].deposit.request.tokenOut = se0;
            else if (i_ == 21) a_.legs[0].deposit.request.holder = detf;
            else if (i_ == 22) a_.legs[0].deposit.request.mode = Frozen.Mode.OrdinaryDeposit;
            else if (i_ == 23) a_.legs[0].deposit.token0 = pairA;
            else if (i_ == 24) a_.legs[0].deposit.token1 = pairB;
            else if (i_ == 25) a_.legs[0].deposit.supply = 1;
            else if (i_ == 26) a_.legs[0].deposit.reserve0 = 1;
            else if (i_ == 27) a_.legs[0].deposit.reserve1 = 1;
            else a_.legs[0].deposit.minimumLiquidity = 1;
            vm.prank(migrationOwner);
            vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
            allocation.setMigrationWeightedPricing(a_);
            assertEq(abi.encode(migration.migrationWeightedPricing()), before_);
        }
    }

    /// @notice Buffer identity and decimal constraints are structural, never calls to the supplied exchange.
    function test_InvalidManual_BufferModelsScalesAndOutput() public {
        _set(_rawInputs());
        bytes memory before_ = abi.encode(migration.migrationWeightedPricing());
        for (uint256 i_; i_ < 15; ++i_) {
            Pricing.Inputs memory a_ = _rawInputs();
            a_.legs[0] = _buffer(a_.legs[0]);
            if (i_ == 0) a_.legs[0].standardExchange = address(0);
            else if (i_ == 1) a_.legs[0].standardExchange = pairA;
            else if (i_ == 2) a_.legs[0].rate = 0;
            else if (i_ == 3) a_.legs[0].deposit.model = Frozen.Model.Unsupported;
            else if (i_ == 4) a_.legs[0].deposit.exchange = address(0xBAD);
            else if (i_ == 5) a_.legs[0].deposit.request.mode = Frozen.Mode.OrdinaryRedemption;
            else if (i_ == 6) a_.legs[0].deposit.request.tokenOut = pairB;
            else if (i_ == 7) a_.legs[0].deposit.request.tokenIn = pairB;
            else if (i_ == 8) a_.legs[0].deposit.request.holder = detf;
            else if (i_ == 9) a_.legs[0].deposit.token0 = address(0);
            else if (i_ == 10) a_.legs[0].deposit.token1 = pairA;
            else if (i_ == 11) a_.legs[0].deposit.token0 = address(0xBAD);
            else if (i_ == 12) a_.legs[2] = _buffer(a_.legs[2]);
            else if (i_ == 13) a_.legs[0].invScale = 1e31;
            else { a_.legs[0].mode = Pricing.LegMode.DisabledBuffer; delete a_.legs[0].deposit; }
            vm.prank(migrationOwner);
            vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
            allocation.setMigrationWeightedPricing(a_);
            assertEq(abi.encode(migration.migrationWeightedPricing()), before_);
        }
    }

    function _buffer(Pricing.Leg memory leg_) private view returns (Pricing.Leg memory) {
        leg_.standardExchange = address(0x1234); // No code: manual validation must never authenticate live state.
        leg_.mode = Pricing.LegMode.EnabledV3Buffer;
        leg_.rate = 1e18;
        leg_.deposit = Frozen.Inputs(Frozen.Model.UniswapV3PairDeposit, leg_.standardExchange,
            Frozen.Request(leg_.token, leg_.standardExchange, address(0), Frozen.Mode.OrdinaryDeposit),
            leg_.token, pairB, 1000 ether, 1000 ether, 1000 ether, 1000);
        return leg_;
    }

    /// @notice All loaders compare even empty batches, before any origin clearing or row mutation.
    function test_StaleBook_AllTwelveEmptyLoaders() public {
        bytes32 a_ = _set(_rawInputs());
        Pricing.Inputs memory b_ = _rawInputs(); b_.swapFeeWad = 1e17;
        bytes32 current_ = _set(b_);
        bytes4[] memory writers_ = _writers();
        for (uint256 i_ = 2; i_ < 14; ++i_) {
            vm.prank(migrationOwner);
            (bool ok_, bytes memory reason_) = detf.call(abi.encodeWithSelector(writers_[i_], new uint256[](0), a_));
            assertFalse(ok_);
            assertEq(reason_, abi.encodeWithSelector(Pricing.MigrationWeightedPricingBookMismatch.selector, a_, current_));
            vm.prank(migrationOwner);
            (ok_, reason_) = detf.call(abi.encodeWithSelector(writers_[i_], new uint256[](0), current_));
            assertTrue(ok_, string(reason_));
        }
        assertEq(IERC20(detf).totalSupply(), 0);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    /// @notice A-issued economics persist through a B setter and explicit same-recipient B replacement.
    function test_ManualBook_StoredCreditAndIssuedBondSurviveReplacement() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("pricing original"));
        uint256 id_ = _issue(address(this));
        bytes memory a_ = abi.encode(migration.independentAllocation(address(this)));
        bytes memory issued_ = abi.encode(migration.independentIssuance(address(this)));
        bytes memory position_ = abi.encode(bonds.positionOf(id_));
        bytes memory stake_ = abi.encode(receipt.stakingState());
        uint256 supply_ = IERC20(detf).totalSupply();
        Pricing.Inputs memory b_ = migration.migrationWeightedPricing().inputs;
        b_.swapFeeWad = 1e17;
        _set(b_);
        assertEq(abi.encode(migration.independentAllocation(address(this))), a_);
        _configure(address(this), 1 ether, bytes32("pricing original"));
        assertNotEq(abi.encode(migration.independentAllocation(address(this))), a_);
        assertEq(abi.encode(migration.independentIssuance(address(this))), issued_);
        assertEq(abi.encode(bonds.positionOf(id_)), position_);
        assertEq(abi.encode(receipt.stakingState()), stake_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        Migration.IndependentIssuanceRequest[] memory requests_ = new Migration.IndependentIssuanceRequest[](1);
        requests_[0] = Migration.IndependentIssuanceRequest(address(this), migration.independentAllocation(address(this)).configurationId);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.IndependentAllocationAlreadyIssued.selector, address(this)));
        allocation.issueIndependentAllocations(requests_);
    }

    /// @notice NFT economic identities remain stable without pricing and keep cross-representation exclusions.
    function test_OriginCollision_StableAcrossBooksAndIndependentIssuance() public {
        vm.chainId(4663);
        bytes32 origin_ = migration.migrationNftOriginalId(NFT, 3);
        assertEq(origin_, keccak256(abi.encode("migration.nft", block.chainid, detf, NFT, uint256(3))));
        _fundAndCapture();
        _configure(address(this), 1 ether, origin_);
        _issue(address(this));
        _configure(address(this), 1 ether, bytes32("other origin"));
        Pricing.Inputs memory b_ = migration.migrationWeightedPricing().inputs; b_.swapFeeWad = 1e17;
        _set(b_);
        assertEq(migration.migrationNftOriginalId(NFT, 3), origin_);
        Migration.NftEntitlementInput[] memory nft_ = new Migration.NftEntitlementInput[](1);
        nft_[0] = Migration.NftEntitlementInput(NFT, 3, address(this), 1, 1 ether, 0, bytes32("evidence"), true);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, origin_));
        allocation.configureNftEntitlements(nft_, pricingId);
        assertEq(migration.nftEntitlement(NFT, 3).configurationId, bytes32(0));
    }

    /// @notice The paid owner purchase does not close the setter; only activation removes it.
    function test_ManualBook_SetAfterPaidOwnerPurchase() public {
        _fundReserve();
        uint256 id_ = _buyOwnerFirstBond();
        bytes memory before_ = abi.encode(bonds.positionOf(id_));
        _set(_rawInputs());
        assertEq(abi.encode(bonds.positionOf(id_)), before_);
    }

    function _writers() private pure returns (bytes4[] memory s_) {
        s_ = new bytes4[](16);
        s_[0] = Allocation.bootstrapMigrationReserve.selector;
        s_[1] = Allocation.setMigrationWeightedPricing.selector;
        s_[2] = Allocation.configureIndependentAllocations.selector;
        s_[3] = Allocation.configureNftEntitlements.selector;
        s_[4] = Allocation.configureNftContributionEntitlements.selector;
        s_[5] = Allocation.configureWeightedLiquidEntitlements.selector;
        s_[6] = Allocation.configureWeightedSyEntitlements.selector;
        s_[7] = Allocation.configureClaimedSyEntitlements.selector;
        s_[8] = Allocation.configureDtfCustodySeEntitlements.selector;
        s_[9] = Allocation.configureClaimVaultEntitlements.selector;
        s_[10] = Allocation.configureWeightedReceiptEntitlements.selector;
        s_[11] = Allocation.configureEarlierReceiptEntitlements.selector;
        s_[12] = Allocation.configureEarlierLiquidEntitlements.selector;
        s_[13] = Allocation.configureHeldSeLpEntitlements.selector;
        s_[14] = Allocation.issueIndependentAllocations.selector;
        s_[15] = Allocation.activateMigration.selector;
    }

    /// @notice Actual loupe addresses prove atomic retirement without a pricing or entitlement readiness gate.
    function test_ActivationCut_UnsetPricingAndEmptyEntitlements() public {
        _fundReserve();
        bytes4[] memory writers_ = _writers();
        address[] memory before_ = new address[](writers_.length);
        for (uint256 i_; i_ < writers_.length; ++i_) {
            before_[i_] = IDiamondLoupe(detf).facetAddress(writers_[i_]);
            assertNotEq(before_[i_], address(0));
        }
        bytes4[3] memory old_ = [bytes4(keccak256("captureMigrationSnapshot()")),
            bytes4(keccak256("migrationSnapshot()")), bytes4(keccak256("migrationSnapshotSource()"))];
        address[3] memory oldBefore_;
        for (uint256 i_; i_ < old_.length; ++i_) {
            oldBefore_[i_] = IDiamondLoupe(detf).facetAddress(old_[i_]);
            assertEq(oldBefore_[i_], address(0));
        }
        vm.prank(migrationOwner);
        vm.expectRevert(Migration.MigrationOwnerFirstBondRequired.selector);
        allocation.activateMigration();
        _buyOwnerFirstBond();
        vm.prank(migrationOwner); allocation.activateMigration();
        address[] memory after_ = new address[](writers_.length);
        for (uint256 i_; i_ < writers_.length; ++i_) {
            after_[i_] = IDiamondLoupe(detf).facetAddress(writers_[i_]);
            assertEq(after_[i_], address(0));
        }
        assertTrue(migration.migrationActivated());
        assertFalse(IERC165(detf).supportsInterface(type(Allocation).interfaceId));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.migrationWeightedPricing.selector), address(0));
        assertNotEq(IDiamondLoupe(detf).facetAddress(Migration.previewOriginalCredit.selector), address(0));
        vm.expectRevert(Pricing.MigrationWeightedPricingNotSet.selector);
        migration.migrationWeightedPricing();
        vm.expectRevert(Pricing.MigrationWeightedPricingNotSet.selector);
        migration.previewOriginalCredit(0, 0);
        bytes memory encodedSelectors_ = abi.encode(writers_);
        emit log_named_bytes("proxy writers ABI", encodedSelectors_);
        emit log_named_bytes("proxy owners before ABI", abi.encode(before_));
        emit log_named_bytes("proxy owners after ABI", abi.encode(after_));
        emit log_named_bytes("old aliases ABI", abi.encode(old_));
        emit log_named_bytes("old alias owners before ABI", abi.encode(oldBefore_));
        address[3] memory oldAfter_;
        for (uint256 i_; i_ < old_.length; ++i_) {
            oldAfter_[i_] = IDiamondLoupe(detf).facetAddress(old_[i_]);
            assertEq(oldAfter_[i_], address(0));
        }
        emit log_named_bytes("old alias owners after ABI", abi.encode(oldAfter_));
        emit log_named_bytes("retained readers ABI", abi.encode(Migration.migrationWeightedPricing.selector,
            IDiamondLoupe(detf).facetAddress(Migration.migrationWeightedPricing.selector),
            Migration.previewOriginalCredit.selector, IDiamondLoupe(detf).facetAddress(Migration.previewOriginalCredit.selector)));
    }

    /// @notice Raw providers floor native units before scaling; disabled buffers rate inventory only.
    function test_ManualMath_AllFourModesAndAmountDependentV3() public {
        MigrationSnapshotMathExposure math_ = _math();
        Pricing.Inputs memory a_ = _rawInputs();
        a_.seigniorage = 0; a_.swapFeeWad = 0;
        _set(a_);
        Pricing.Result memory raw_ = math_.evaluate(migration.migrationWeightedPricing(), address(0), 1 ether + 1);
        assertEq(raw_.ratedInflow, 1 ether + 1);
        a_.legs[0].mode = Pricing.LegMode.RawRate;
        a_.legs[0].rate = 15e17;
        _set(a_);
        Pricing.Result memory rate_ = math_.evaluate(migration.migrationWeightedPricing(), address(0), 1 ether + 1);
        assertEq(rate_.ratedInflow, 15e17 + 1, "floor native provider product before scale");
        a_.legs[0].mode = Pricing.LegMode.DisabledBuffer;
        a_.legs[0].standardExchange = address(0x1234);
        a_.legs[0].seReserve = 100 ether;
        _set(a_);
        Pricing.Result memory disabled_ = math_.evaluate(migration.migrationWeightedPricing(), address(0), 1 ether + 1);
        assertEq(disabled_.ratedInflow, 1 ether + 1, "disabled input is not rate multiplied");
        assertLt(disabled_.user, raw_.user, "held SE inventory is still rated");
        a_.legs[0] = _buffer(a_.legs[0]);
        _set(a_);
        Pricing.Result memory enabled_ = math_.evaluate(migration.migrationWeightedPricing(), address(0), 1 ether);
        Pricing.Result memory twice_ = math_.evaluate(migration.migrationWeightedPricing(), address(0), 2 ether);
        assertNotEq(twice_.ratedInflow, 2 * enabled_.ratedInflow, "V3 deposit depends on amount");
        assertEq(migration.previewOriginalCredit(1 ether, 1 ether), enabled_.user
            + math_.evaluate(migration.migrationWeightedPricing(), pairB, 1 ether).user);
        emit log_named_bytes("manual mode vectors", abi.encode(raw_, rate_, disabled_, enabled_, twice_));
    }

    /// @notice SE native 6/18/24/36 operands map through the existing denominator and single scaling step.
    function test_ManualMath_SeDecimalMappingAndNoLiveCalls() public {
        MigrationSnapshotMathExposure math_ = _math();
        uint256[4] memory decimals_ = [uint256(6), 18, 24, 36];
        for (uint256 i_; i_ < 4; ++i_) {
            Pricing.Inputs memory a_ = _rawInputs();
            a_.legs[0] = _buffer(a_.legs[0]);
            uint256 units_ = 10 ** decimals_[i_];
            a_.legs[0].invScale = 10 ** (36 - decimals_[i_]);
            a_.legs[0].seReserve = 100 * units_;
            a_.legs[0].deposit.supply = 1000 * units_;
            vm.record();
            _set(a_);
            Pricing.Result memory r_ = math_.evaluate(migration.migrationWeightedPricing(), address(0), 1 ether);
            (bytes32[] memory reads_, bytes32[] memory writes_) = vm.accesses(address(0x1234));
            assertEq(reads_.length, 0); assertEq(writes_.length, 0);
            uint256 quotedShares_ = math_.v3Shares(a_.legs[0].deposit, r_.net);
            assertEq(r_.ratedInflow, Weighted.ratedPairUnits(quotedShares_, 1e18, a_.legs[0].invScale, 1e18));
            emit log_named_bytes("decimal vector", abi.encode(decimals_[i_], a_, r_));
        }
    }

    /// @notice Uplift, checked fee product and final user split each execute once.
    function test_ManualMath_FeeAndSeigniorageOnceIncludingFullPercentage() public {
        _fundReserve();
        MigrationSnapshotMathExposure math_ = _math();
        Pricing.Inputs memory a_ = _rawInputs();
        _set(a_);
        Pricing.Result memory r_ = math_.evaluate(migration.migrationWeightedPricing(), address(0), 1 ether + 17);
        assertEq(r_.boosted, (uint256(1 ether) + 17) * 105 / 100);
        assertEq(r_.net, r_.boosted - r_.boosted * 3e15 / 1e18);
        assertEq(r_.user, r_.gross * 95 / 100);
        assertEq(migration.previewOriginalCredit(0, 0), 0);
        a_.seigniorage = 1e18;
        _set(a_);
        assertEq(migration.previewOriginalCredit(1 ether, 0), 0);
        _configure(address(this), 1 ether, bytes32("zero user"));
        Migration.IndependentIssuanceRequest[] memory requests_ = new Migration.IndependentIssuanceRequest[](1);
        requests_[0] = Migration.IndependentIssuanceRequest(address(this), migration.independentAllocation(address(this)).configurationId);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidIndependentAllocation.selector, address(this)));
        allocation.issueIndependentAllocations(requests_);
    }



    /// @notice A malformed arithmetic operand rolls back; evaluation overflow bubbles canonical panic bytes.
    function test_PricingRollback_CheckedOverflow() public {
        _set(_rawInputs());
        bytes memory before_ = abi.encode(migration.migrationWeightedPricing());
        Pricing.Inputs memory a_ = _rawInputs();
        a_.legs[0].rawReserve = type(uint256).max;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        allocation.setMigrationWeightedPricing(a_);
        assertEq(abi.encode(migration.migrationWeightedPricing()), before_);
        a_ = _rawInputs(); a_.seigniorage = 0;
        _set(a_);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        migration.previewOriginalCredit(type(uint256).max, 0);
    }

    /// @notice Exactly 30 percent mapped inflow is accepted; the next native unit is rejected.
    function test_MaxIn_RawBoundaryAndNativeOutputCap() public {
        Pricing.Inputs memory a_ = _rawInputs();
        a_.swapFeeWad = 0; a_.seigniorage = 0;
        _set(a_);
        assertGt(migration.previewOriginalCredit(300 ether, 0), 0);
        vm.expectRevert(Weighted.MaxInRatio.selector);
        migration.previewOriginalCredit(300 ether + 1, 0);
        a_.legs[2].mode = Pricing.LegMode.RawRate; a_.legs[2].rate = 100e18;
        _set(a_);
        vm.expectRevert(Weighted.WouldZeroReserve.selector);
        migration.previewOriginalCredit(100 ether, 0);
    }

    /// @notice Dust and authoritative zero-supply/zero-backing operands use canonical zero-output rejection.
    function test_ZeroOutput_NativeFloorAndEmptyV3() public {
        Pricing.Inputs memory a_ = _rawInputs();
        a_.swapFeeWad = 0; a_.seigniorage = 0;
        _set(a_);
        vm.expectRevert(Weighted.ZeroAmount.selector);
        migration.previewOriginalCredit(1, 0);
        a_.legs[0] = _buffer(a_.legs[0]); a_.legs[0].deposit.supply = 0;
        _set(a_);
        vm.expectRevert(Weighted.ZeroAmount.selector);
        migration.previewOriginalCredit(1 ether, 0);
    }

    /// @notice An eight-leg book preserves order and permits unused zero balances, but never a zero rate denominator.
    function test_InvalidManual_AuxiliaryDenominatorAndDisabledUnusedRate() public {
        Pricing.Inputs memory a_ = _rawInputs();
        Pricing.Leg[] memory legs_ = new Pricing.Leg[](8);
        for (uint256 i_; i_ < 3; ++i_) legs_[i_] = a_.legs[i_];
        legs_[0].weight -= 5e16;
        for (uint256 i_ = 3; i_ < 8; ++i_) {
            legs_[i_].token = address(uint160(100 + i_));
            legs_[i_].weight = 1e16;
            legs_[i_].invScale = 1;
            legs_[i_].ratedScale = 1;
        }
        a_.legs = legs_;
        _set(a_);
        assertEq(abi.encode(migration.migrationWeightedPricing().inputs), abi.encode(a_));
        a_.legs[3].mode = Pricing.LegMode.DisabledBuffer;
        a_.legs[3].standardExchange = address(0x1234);
        a_.legs[3].seReserve = 1;
        a_.legs[3].rate = 1;
        a_.legs[3].invScale = 1e30;
        vm.prank(migrationOwner); vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
        allocation.setMigrationWeightedPricing(a_);
        a_.legs[3].seReserve = 0; a_.legs[3].rate = 0;
        _set(a_); // This unused conversion has no denominator requirement.
        a_ = _rawInputs();
        a_.legs[0].mode = Pricing.LegMode.DisabledBuffer;
        a_.legs[0].standardExchange = address(0x1234);
        _set(a_);
        a_.legs[0].seReserve = 1;
        vm.prank(migrationOwner); vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
        allocation.setMigrationWeightedPricing(a_);
        a_ = _rawInputs(); a_.legs[0].rawReserve = 0;
        vm.prank(migrationOwner); vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
        allocation.setMigrationWeightedPricing(a_);
    }

    /// @notice A stale independent replacement cannot clear the old origin index or change its stored credit.
    function test_StaleBook_IndependentOriginIndexRemainsAllocated() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("retained origin"));
        bytes memory before_ = abi.encode(migration.independentAllocation(address(this)));
        bytes32 old_ = pricingId;
        Pricing.Inputs memory b_ = migration.migrationWeightedPricing().inputs; b_.swapFeeWad = 1e17;
        _set(b_);
        Migration.IndependentAllocationInput[] memory a_ = new Migration.IndependentAllocationInput[](1);
        a_[0].recipient = address(this);
        a_[0].entitlements = new Migration.OriginalEntitlement[](1);
        a_[0].entitlements[0] = Migration.OriginalEntitlement(bytes32("replacement"), 1 ether, 0, bytes32("evidence"));
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Pricing.MigrationWeightedPricingBookMismatch.selector, old_, pricingId));
        allocation.configureIndependentAllocations(a_, old_);
        assertEq(abi.encode(migration.independentAllocation(address(this))), before_);
        vm.expectRevert(abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, bytes32("retained origin")));
        _configure(address(0xBEEF), 1 ether, bytes32("retained origin"));
        assertEq(migration.independentAllocation(address(0xBEEF)).configurationId, bytes32(0));
    }

    /// @notice Separate NFT originals retain both A credits across B until an explicit complete B replacement.
    function test_StaleBook_SeparateNftPreservesStableOriginAndBothCredits() public {
        vm.chainId(4663); _fundAndCapture();
        Migration.NftEntitlementInput[] memory a_ = new Migration.NftEntitlementInput[](1);
        a_[0] = Migration.NftEntitlementInput(NFT, 3, address(this), 1, 1 ether, 2 ether, bytes32("evidence"), true);
        vm.prank(migrationOwner); allocation.configureNftContributionEntitlements(a_, pricingId);
        bytes32 origin_ = migration.migrationNftOriginalId(NFT, 3);
        bytes memory before_ = abi.encode(migration.nftEntitlement(NFT, 3), migration.nftContributions(NFT, 3));
        bytes32 old_ = pricingId;
        Pricing.Inputs memory b_ = migration.migrationWeightedPricing().inputs; b_.swapFeeWad = 1e17;
        _set(b_);
        assertEq(abi.encode(migration.nftEntitlement(NFT, 3), migration.nftContributions(NFT, 3)), before_);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Pricing.MigrationWeightedPricingBookMismatch.selector, old_, pricingId));
        allocation.configureNftContributionEntitlements(a_, old_);
        assertEq(abi.encode(migration.nftEntitlement(NFT, 3), migration.nftContributions(NFT, 3)), before_);
        vm.prank(migrationOwner); allocation.configureNftContributionEntitlements(a_, pricingId);
        assertEq(migration.nftEntitlement(NFT, 3).originalId, origin_);
        assertEq(migration.nftEntitlement(NFT, 3).configurationId,
            keccak256(abi.encode(block.chainid, detf, pricingId, a_[0], true)));
        Migration.NftContribution[] memory parts_ = migration.nftContributions(NFT, 3);
        assertEq(parts_[0].credit, migration.previewOriginalCredit(1 ether, 0));
        assertEq(parts_[1].credit, migration.previewOriginalCredit(0, 2 ether));
        assertFalse(migration.nftSurrender(NFT, 3).consumed);
        assertEq(migration.nftCustody(NFT, 3).collection, address(0));
    }
}
