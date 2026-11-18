// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {console2} from "forge-std/console2.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/IFeeCollectorDFPkg.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IIndexedexManagerDFPkg} from "contracts/manager/IIndexedexManagerDFPkg.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IntrospectionFacetFactoryService} from "@crane/contracts/introspection/IntrospectionFacetFactoryService.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";


import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation, IUniswapV4DetfMigrationAccounting as Accounting} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IUniswapV4DetfMigrationSY as SY} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSY.sol";
import {IUniswapV4DetfMigrationRewardToken as RT} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";

import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {IUniswapV4DetfMigrationWeightedPricingV3 as PricingV3,
    IUniswapV4DetfMigrationWeightedPricingAllocationV3 as PricingAllocationV3} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricingV3.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";

/// @notice A real contract owner for local QA, controlled by the unlocked dev account.
/// @dev It calls only the production administration API. It cannot mint, supply credit, impersonate
/// the parent, change its storage, or bypass a child. Reading the configuration identity on-chain
/// avoids substituting the simulation's snapshot block provenance for the mined provenance.
contract MigrationCoreLocalOwner {
    using BetterSafeERC20 for IERC20;

    address public immutable controller;
    Migration public parent;
    event MetadataCapture(uint256 indexed tokenId, bool activated, string tokenUri);

    constructor(address controller_) { controller = controller_; }
    modifier onlyController() { require(msg.sender == controller, "controller"); _; }
    function bind(Migration parent_) external onlyController {
        require(address(parent) == address(0) && parent_.owner() == address(this), "fixed real owner");
        parent = parent_;
    }
    function bootstrap(Migration.GenesisLeg[] calldata legs_) external onlyController {
        Allocation(address(parent)).bootstrapMigrationReserve(legs_, 0, 1, block.timestamp);
    }
    function setConfigureIssue(uint256 originalEth_, uint256 originalDtf_, Pricing.InputsV3 calldata pricing_)
        external onlyController returns (uint256 credit_, uint256 id_)
    {
        Allocation admin_ = Allocation(address(parent));
        bytes32 bookId_ = PricingAllocationV3(address(parent)).setMigrationWeightedPricingV3(pricing_);
        Migration.IndependentAllocationInput[] memory inputs_ = new Migration.IndependentAllocationInput[](1);
        inputs_[0].recipient = controller;
        inputs_[0].evidenceId = keccak256("external QA fixture; not historical provenance");
        inputs_[0].entitlements = new Migration.OriginalEntitlement[](1);
        inputs_[0].entitlements[0] = Migration.OriginalEntitlement(
            bytes32("local-original"), originalEth_, originalDtf_, bytes32("fixture")
        );
        uint256 supply_ = IERC20(address(parent)).totalSupply();
        admin_.configureIndependentAllocations(inputs_, bookId_);
        require(IERC20(address(parent)).totalSupply() == supply_, "configuration mints nothing");
        Migration.IndependentAllocation memory configured_ = parent.independentAllocation(controller);
        credit_ = configured_.totalCredit;
        Migration.IndependentIssuanceRequest[] memory requests_ = new Migration.IndependentIssuanceRequest[](1);
        requests_[0] = Migration.IndependentIssuanceRequest(controller, configured_.configurationId);
        id_ = admin_.issueIndependentAllocations(requests_)[0];
        require(IERC20(address(parent)).totalSupply() == supply_ + credit_, "exact genuine issuance");
    }
    /// @notice Pays for the current owner's ordinary bond using only fresh controller funds.
    function buyOwnerFirstBond(IERC20 token_, uint256 amount_, uint256 duration_, uint256 deadline_)
        external onlyController returns (uint256 bondId_, uint256 lpOut_)
    {
        uint256 surplus_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(controller, address(this), amount_);
        require(token_.balanceOf(address(this)) - surplus_ == amount_, "exact fresh payment");
        token_.forceApprove(address(parent), amount_);
        (bondId_, lpOut_) = parent.bond(token_, amount_, duration_, controller, false, deadline_);
        token_.forceApprove(address(parent), 0);
        require(token_.balanceOf(address(this)) == surplus_, "preserved helper surplus");
    }
    function activate() external onlyController {
        uint256 compensationId_ = parent.independentIssuance(controller).bondTokenId;
        uint256 paidId_ = parent.migrationOwnerFirstBondTokenId();
        IERC721Metadata metadata_ = IERC721Metadata(parent.bondNftVault());
        emit MetadataCapture(compensationId_, false, metadata_.tokenURI(compensationId_));
        emit MetadataCapture(paidId_, false, metadata_.tokenURI(paidId_));
        Allocation(address(parent)).activateMigration();
        emit MetadataCapture(compensationId_, true, metadata_.tokenURI(compensationId_));
        emit MetadataCapture(paidId_, true, metadata_.tokenURI(paidId_));
    }
}

/// @notice Bounded two-stage QA on the guarded owned 18548 Anvil; not a resumable legacy operator.
contract MigrationCoreLocalQA is TestBase_UniswapV4DetfMigration {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using IntrospectionFacetFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for IDiamondPackageCallBackFactory;
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;
    using IndexedexManagerFactoryService for IDiamondPackageCallBackFactory;


    using VaultComponentFactoryService for ICreate3FactoryProxy;
    address internal constant DEV = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant RECEIVER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    event CoreDeployed(address indexed parent, address receipt, address bond, address rawSy, address stakingSy, address rewardToken);
    event CorePrincipalPaid(address indexed parent, uint256 amount, uint256 deferredBondRewards);
    event CoreRewardsPaid(address indexed parent, uint256 bondRewards, uint256 nativeRT, uint256 redeemed, uint256 remainder);
    event CoreBonds(address indexed parent, address indexed helper, uint256 compensationId, uint256 paidId);
    event CoreDonationSweep(address indexed parent, uint256 lpBefore, uint256 lpAfter, uint256 recoveryA, uint256 recoveryB, uint256 receiptBacking);
    function setUp() public override {}

    function _localInfrastructure() internal {
        (create3Factory, diamondPackageFactory) = InitDevService.initEnv(DEV);
        diamondFactory = diamondPackageFactory;
        owner = DEV;
            multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();
            vm.label(address(multiStepOwnableFacet), "multiStepOwnableFacet");
            diamondCutFacet = create3Factory.deployDiamondCutFacet();
            vm.label(address(diamondCutFacet), "diamondCutFacet");
            feeCollectorManagerFacet = create3Factory.deployFeeCollectorManagerFacet();
            vm.label(address(feeCollectorManagerFacet), "feeCollectorManagerFacet");
            feeCollectorSingleTokenPushFacet = create3Factory.deployFeeCollectorSingleTokenPushFacet();
            vm.label(address(feeCollectorSingleTokenPushFacet), "feeCollectorSingleTokenPushFacet");
            feeCollectorDFPkg = create3Factory.deployFeeCollectorDFPkg(
                diamondCutFacet, multiStepOwnableFacet, feeCollectorSingleTokenPushFacet, feeCollectorManagerFacet
            );
            vm.label(address(feeCollectorDFPkg), "feeCollectorDFPkg");
            feeCollector = diamondPackageFactory.deployFeeCollector(
                // IDiamondPackageCallBackFactory diamondFactory,
                // IFeeCollectorDFPkg feeCollectorDFPkg,
                feeCollectorDFPkg,
                // address owner
                owner
            );
            vm.label(address(feeCollector), "feeCollector");

            vaultFeeOracleQueryFacet = create3Factory.deployVaultFeeOracleQueryFacet();
            vm.label(address(vaultFeeOracleQueryFacet), "vaultFeeOracleQueryFacet");
            vaultFeeOracleManagerFacet = create3Factory.deployVaultFeeOracleManagerFacet();
            vm.label(address(vaultFeeOracleManagerFacet), "vaultFeeOracleManagerFacet");
            vaultRegistryDeploymentFacet = create3Factory.deployVaultRegistryDeploymentFacet();
            vm.label(address(vaultRegistryDeploymentFacet), "vaultRegistryDeploymentFacet");
            vaultRegistryVaultManagerFacet = create3Factory.deployVaultRegistryVaultManagerFacet();
            vm.label(address(vaultRegistryVaultManagerFacet), "vaultRegistryVaultManagerFacet");
            vaultRegistryVaultPackageManagerFacet = create3Factory.deployVaultRegistryVaultPackageManagerFacet();
            vm.label(address(vaultRegistryVaultPackageManagerFacet), "vaultRegistryVaultPackageManagerFacet");
            vaultRegistryVaultPackageQueryFacet = create3Factory.deployVaultRegistryVaultPackageQueryFacet();
            vm.label(address(vaultRegistryVaultPackageQueryFacet), "vaultRegistryVaultPackageQueryFacet");
            vaultRegistryVaultQueryFacet = create3Factory.deployVaultRegistryVaultQueryFacet();
            vm.label(address(vaultRegistryVaultQueryFacet), "vaultRegistryVaultQueryFacet");
            vaultRegistryDisableQueryFacet = create3Factory.deployVaultRegistryDisableQueryFacet();
            vm.label(address(vaultRegistryDisableQueryFacet), "vaultRegistryDisableQueryFacet");
            vaultRegistryDisableManagerFacet = create3Factory.deployVaultRegistryDisableManagerFacet();
            vm.label(address(vaultRegistryDisableManagerFacet), "vaultRegistryDisableManagerFacet");
            // deploy operableFacet and include it in the manager package so operator tests use the real operable implementation
            IFacet operableFacet = create3Factory.deployOperableFacet();
            vm.label(address(operableFacet), "operableFacet");

            indexedexManagerDFPkg = create3Factory.deployIndexedexManagerDFPkg(
                IIndexedexManagerDFPkg.PkgInit({
                    diamondCutFacet: diamondCutFacet,
                    multiStepOwnableFacet: multiStepOwnableFacet,
                    vaultFeeQueryFacet: vaultFeeOracleQueryFacet,
                    vaultFeeManagerFacet: vaultFeeOracleManagerFacet,
                    operableFacet: operableFacet,
                    vaultRegistryDeploymentFacet: vaultRegistryDeploymentFacet,
                    vaultRegistryVaultManagerFacet: vaultRegistryVaultManagerFacet,
                    vaultRegistryVaultPackageManagerFacet: vaultRegistryVaultPackageManagerFacet,
                    vaultRegistryVaultPackageQueryFacet: vaultRegistryVaultPackageQueryFacet,
                    vaultRegistryVaultQueryFacet: vaultRegistryVaultQueryFacet,
                    vaultRegistryDisableQueryFacet: vaultRegistryDisableQueryFacet,
                    vaultRegistryDisableManagerFacet: vaultRegistryDisableManagerFacet
                })
            );
            vm.label(address(indexedexManagerDFPkg), "indexedexManagerDFPkg");
            indexedexManager = diamondPackageFactory.deployIndexedexManager(
                create3Factory, indexedexManagerDFPkg, owner, feeCollector
            );
            vm.label(address(indexedexManager), "indexedexManager");
            // Register IndexedexManager as an operator on Create3Factory so it can deploy packages
            IOperable(address(create3Factory)).setOperator(address(indexedexManager), true);
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERC5267Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

        permit2 = IPermit2(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "BetterPermit2.sol:BetterPermit2"), "", keccak256("migration.qa.permit2")
        ));
    }

    function deployAndIssue() external {
        require(block.chainid == 31337, "local chain only");
        localBroadcast = true; payer = DEV;
        vm.startBroadcast();
        _localInfrastructure();
        MigrationCoreLocalOwner account_ = MigrationCoreLocalOwner(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MigrationCoreLocalQA.s.sol:MigrationCoreLocalOwner"),
            abi.encode(DEV), keccak256("migration.qa.owner")
        ));
        migrationOwner = address(account_);
        _migrationEnvironment();
        account_.bind(migration);
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA); tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100 ether; amounts_[1] = 100 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp + 1 hours);
        Migration.GenesisLeg[] memory legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), 50 ether, 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), 50 ether, 1);
        account_.bootstrap(legs_);
        uint256 donationA_ = migration.migrationDonationInventory(IERC20(pairA));
        uint256 donationB_ = migration.migrationDonationInventory(IERC20(pairB));
        require(donationA_ > 0 && donationB_ > 0, "original donation remainders");
        (uint256 credit_, uint256 id_) = account_.setConfigureIssue(1 ether, 1 ether, _manualInputs());
        require(id_ == 3 && bonds.positionOf(id_).principal == credit_, "actual independent principal");
        require(receipt.stakingState().accountedBacking == credit_, "measured backing");
        require(IERC20(detf).balanceOf(address(receipt)) == credit_, "actual backing custody");
        uint256 paymentBefore_ = IERC20(pairA).balanceOf(DEV);
        IERC20(pairA).approve(address(account_), 1 ether);
        (uint256 purchasedId_, uint256 lpOut_) =
            account_.buyOwnerFirstBond(IERC20(pairA), 1 ether, 90 days, block.timestamp + 1 hours);
        uint256 compensationId_ = migration.independentIssuance(DEV).bondTokenId;
        uint256 paidId_ = migration.migrationOwnerFirstBondTokenId();
        require(compensationId_ == 3 && paidId_ == 4 && purchasedId_ == paidId_, "queried reservation order");
        require(bonds.positionOf(compensationId_).principal == credit_
            && bonds.isMigrationPosition(compensationId_)
            && bonds.positionOf(compensationId_).vestingDuration == 90 days, "separate compensation cliff");
        require(lpOut_ > 0 && bonds.positionOf(paidId_).principal > 0
            && !bonds.isMigrationPosition(paidId_) && bonds.positionOf(paidId_).vestingDuration == 90 days
            && IERC721(address(bonds)).ownerOf(paidId_) == DEV, "funded ordinary owner purchase");
        require(paymentBefore_ - IERC20(pairA).balanceOf(DEV) == 1 ether
            && IERC20(pairA).balanceOf(address(account_)) == 0, "actual separate payment");
        require(IERC20(pairA).allowance(DEV, address(account_)) == 0
            && IERC20(pairA).allowance(address(account_), detf) == 0, "cleared payment allowances");
        require(migration.migrationDonationInventory(IERC20(pairA)) == donationA_
            && migration.migrationDonationInventory(IERC20(pairB)) == donationB_, "purchase preserves donation books");
        emit CoreBonds(detf, address(account_), compensationId_, paidId_);
        emit CoreDeployed(detf, address(receipt), address(bonds), address(rawSy), address(stakingSy), migration.migrationSyRewardToken());
        vm.stopBroadcast();
        console2.log("MIGRATION_PARENT", detf);
        console2.log("MIGRATION_HELPER", address(account_));
        console2.log("MIGRATION_BOND", address(bonds));
        console2.log("MIGRATION_RECEIPT", address(receipt));
        console2.log("MIGRATION_RAW_SY", address(rawSy));
        console2.log("MIGRATION_STAKING_SY", address(stakingSy));
        console2.log("MIGRATION_REWARD_TOKEN", migration.migrationSyRewardToken());
        console2.log("MIGRATION_COMPENSATION_ID", compensationId_);
        console2.log("MIGRATION_PAID_ID", paidId_);
        console2.log("MIGRATION_CREDIT", credit_);
    }

    function exerciseAfterCliff(address parentAddress_) external {
        require(block.chainid == 31337 && parentAddress_.code.length != 0, "local deployed parent");
        Migration parent_ = Migration(parentAddress_);
        MigrationCoreLocalOwner account_ = MigrationCoreLocalOwner(parent_.owner());
        require(account_.controller() == DEV && address(account_.parent()) == parentAddress_
            && !parent_.migrationActivated(), "current owner Stage1");
        Bonds bond_ = Bonds(parent_.bondNftVault());
        MigrationReceipt receipt_ = MigrationReceipt(parent_.rebasingClaimToken());
        SY sy_ = SY(parent_.stakingSY());
        uint256 compensationId_ = parent_.independentIssuance(DEV).bondTokenId;
        uint256 paidId_ = parent_.migrationOwnerFirstBondTokenId();
        require(paidId_ != 0 && paidId_ != compensationId_ && bond_.positionOf(paidId_).principal > 0
            && !bond_.isMigrationPosition(paidId_) && IERC721(address(bond_)).ownerOf(paidId_) == DEV
            && bond_.positionOf(paidId_).vestingDuration == 90 days, "real paid prerequisite");
        uint256 principal_ = bond_.positionOf(compensationId_).principal;
        require(bond_.isMigrationPosition(compensationId_)
            && block.timestamp >= bond_.positionOf(compensationId_).startTimestamp + 90 days, "mine actual cliff before stage B");
        address input_ = PricingV3(address(parent_)).migrationWeightedPricingV3().weth;
        address other_ = PricingV3(address(parent_)).migrationWeightedPricingV3().originalDtf;
        uint256 donationA_ = parent_.migrationDonationInventory(IERC20(input_));
        uint256 donationB_ = parent_.migrationDonationInventory(IERC20(other_));
        require(donationA_ > 0 && donationB_ > 0, "old books still positive");
        _assertRewardsClosed(bond_, compensationId_);
        vm.startBroadcast();
        parent_.synchronizeRewards();
        uint256 oldRewards_ = bond_.previewClaim(compensationId_).rewardsDue;
        require(oldRewards_ > 0 && RT(parent_.migrationSyRewardToken()).totalSupply() == 0, "earned unpaid rewards");
        uint256 paid_ = bond_.claimPrincipal(compensationId_, DEV);
        require(paid_ == principal_, "mature principal before activation");
        IERC20(address(receipt_)).approve(address(sy_), paid_ / 2);
        sy_.deposit(DEV, address(receipt_), paid_ / 2, paid_ / 2);
        receipt_.exchangeIn(IERC20(address(receipt_)), paid_ - paid_ / 2, IERC20(address(parent_)), 1, DEV, false, block.timestamp + 1 hours);
        emit CorePrincipalPaid(address(parent_), paid_, oldRewards_);
        require(parent_.migrationDonationInventory(IERC20(input_)) == donationA_
            && parent_.migrationDonationInventory(IERC20(other_)) == donationB_, "principal flow preserves old books");
        account_.activate();
        require(parent_.migrationActivated(), "activated");
        _assertAdministrationRemoved(parent_);
        uint256 rewards_ = bond_.claimRewards(compensationId_, DEV);
        require(rewards_ >= oldRewards_, "old bond owns old rewards");
        IERC20(input_).approve(address(parent_), 1 ether);
        (uint256 laterId_,) = parent_.bond(IERC20(input_), 1 ether, 90 days, DEV, false, block.timestamp + 1 hours);
        require(laterId_ != paidId_ && laterId_ != compensationId_
            && IERC721(address(bond_)).ownerOf(laterId_) == DEV
            && bond_.positionOf(laterId_).principal > 0 && !bond_.isMigrationPosition(laterId_),
            "distinct later ordinary purchase");
        console2.log("MIGRATION_LATER_PAID_ID", laterId_);
        uint256 shares_ = sy_.balanceOf(DEV);
        sy_.transfer(RECEIVER, shares_);
        uint256[] memory claimed_ = sy_.claimRewards(DEV);
        require(claimed_[0] > 0, "departed holder reward tokens");
        RT rt_ = RT(parent_.migrationSyRewardToken());
        (uint256 redeemed_, uint256 remainder_) = rt_.redeem(claimed_[0], RECEIVER, 0);
        sy_.claimRewardRemainder();
        receipt_.claimDeferredRewards(0);
        address feeBeneficiary_ = IERC721(address(bond_)).ownerOf(1);
        address creatorBeneficiary_ = IERC721(address(bond_)).ownerOf(2);
        require(receipt_.claimDeferredRoleRewards(feeBeneficiary_) > 0, "captured role beneficiary paid");
        if (creatorBeneficiary_ != feeBeneficiary_) {
            require(receipt_.claimDeferredRoleRewards(creatorBeneficiary_) > 0, "captured creator paid");
        }
        require(sy_.claimRewards(DEV)[0] == 0, "repeat reward zero");
        require(parent_.migrationDonationInventory(IERC20(input_)) == donationA_
            && parent_.migrationDonationInventory(IERC20(other_)) == donationB_, "lifecycle leaves donations for maintenance");
        emit CoreRewardsPaid(address(parent_), rewards_, claimed_[0], redeemed_, remainder_);
        vm.stopBroadcast();
    }

    /// @notice Separate local maintenance transaction; the parent requires the current feeTo caller.
    function sweepOldDonations(address parentAddress_) external {
        require(block.chainid == 31337 && parentAddress_.code.length != 0, "local deployed parent");
        Migration parent_ = Migration(parentAddress_);
        address input_ = PricingV3(parentAddress_).migrationWeightedPricingV3().weth;
        address other_ = PricingV3(parentAddress_).migrationWeightedPricingV3().originalDtf;
        vm.startBroadcast();
        _sweepOldDonations(
            parent_, Bonds(parent_.bondNftVault()), MigrationReceipt(parent_.rebasingClaimToken()), input_, other_
        );
        vm.stopBroadcast();
    }

    function _assertRewardsClosed(Bonds bond_, uint256 id_) private {
        // Simulation-only negative probes precede the broadcast; no failed claim is mined.
        // Isolated simulation advances the pranked EOA nonce even for reverted
        // calls. Restore that simulation state before collecting real transactions.
        uint256 snapshot_ = vm.snapshotState();
        vm.startPrank(DEV);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bond_.claimRewards(id_, DEV);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bond_.claimBond(id_, DEV);
        vm.stopPrank();
        require(vm.revertToStateAndDelete(snapshot_), "restore simulation-only reward probes");
    }

    function _assertAdministrationRemoved(Migration parent_) private view {
        bytes4[17] memory selectors_ = [
            Allocation.bootstrapMigrationReserve.selector, Allocation.setMigrationWeightedPricing.selector,
            Allocation.configureIndependentAllocations.selector, Allocation.issueIndependentAllocations.selector,
            Allocation.activateMigration.selector, Allocation.configureNftEntitlements.selector,
            Allocation.configureWeightedSyEntitlements.selector, Allocation.configureDtfCustodySeEntitlements.selector,
            Allocation.configureWeightedLiquidEntitlements.selector, Allocation.configureClaimVaultEntitlements.selector,
            Allocation.configureWeightedReceiptEntitlements.selector, Allocation.configureEarlierReceiptEntitlements.selector,
            Allocation.configureEarlierLiquidEntitlements.selector, Allocation.configureHeldSeLpEntitlements.selector,
            Allocation.configureNftContributionEntitlements.selector, Allocation.configureClaimedSyEntitlements.selector,
            PricingAllocationV3.setMigrationWeightedPricingV3.selector
        ];
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            require(IDiamondLoupe(address(parent_)).facetAddress(selectors_[i_]) == address(0), "administration selector removal");
        }
    }

    function _sweepOldDonations(Migration parent_, Bonds bond_, MigrationReceipt receipt_, address input_, address other_)
        private
    {
        uint256 recoveryA_ = Recovery(address(parent_)).migrationRecoveryInventory(input_);
        uint256 recoveryB_ = Recovery(address(parent_)).migrationRecoveryInventory(other_);
        uint256 backing_ = IERC20(address(parent_)).balanceOf(address(receipt_));
        uint256 supply_ = IERC20(address(parent_)).totalSupply();
        uint256 controllerA_ = IERC20(input_).balanceOf(DEV);
        uint256 controllerB_ = IERC20(other_).balanceOf(DEV);
        uint256 lpBefore_ = IERC20(parent_.hook()).balanceOf(address(bond_));
        parent_.sweepDust();
        uint256 lpAfter_ = IERC20(parent_.hook()).balanceOf(address(bond_));
        require(lpAfter_ > lpBefore_, "old capital makes actual LP progress");
        require(parent_.migrationDonationInventory(IERC20(input_)) == 0
            && parent_.migrationDonationInventory(IERC20(other_)) == 0, "old donation books released");
        require(Recovery(address(parent_)).migrationRecoveryInventory(input_) == recoveryA_
            && Recovery(address(parent_)).migrationRecoveryInventory(other_) == recoveryB_
            && IERC20(address(parent_)).balanceOf(address(receipt_)) == backing_
            && IERC20(address(parent_)).totalSupply() == supply_
            && IERC20(input_).balanceOf(DEV) == controllerA_
            && IERC20(other_).balanceOf(DEV) == controllerB_, "protected sweep balances");
        emit CoreDonationSweep(address(parent_), lpBefore_, lpAfter_, recoveryA_, recoveryB_, backing_);
    }
}
