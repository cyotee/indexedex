// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationDFPkg as Package}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";

/// @notice Typed stage simulations. The CLI owns durable intents and submission.
/// @dev No target/calldata executor and no implicit run() or broadcast flag.
contract Phase_08_Stage_01_MigrationExecution is Script {
    function deploy(Package package_, Package.PkgArgs calldata args_) external returns (address proxy_) {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_ = package_.deployVault(args_);
        vm.stopBroadcast();
    }

    function fund(
        Migration proxy_, IERC20[] calldata tokens_, uint256[] calldata amounts_,
        uint256 nativeAmount_, uint256 minimum_, uint256 deadline_
    ) external returns (uint256 lpOut_) {
        require(tokens_.length == amounts_.length, "donation arrays");
        vm.startBroadcast(vm.envAddress("SENDER"));
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            require(tokens_[i_].approve(address(proxy_), amounts_[i_]), "donation approval");
        }
        lpOut_ = proxy_.donateMigrationCapital{value: nativeAmount_}(
            tokens_, amounts_, nativeAmount_, minimum_, deadline_
        );
        vm.stopBroadcast();
    }

    function bootstrap(
        Allocation proxy_, Migration.GenesisLeg[] calldata legs_, uint256 anchor_,
        uint256 minimum_, uint256 deadline_
    ) external returns (uint256 selfMinted_, uint256 lpOut_) {
        vm.startBroadcast(vm.envAddress("SENDER"));
        (selfMinted_, lpOut_) = proxy_.bootstrapMigrationReserve(legs_, anchor_, minimum_, deadline_);
        vm.stopBroadcast();
    }

    function capture(Allocation proxy_) external returns (bytes32 snapshot_) {
        vm.startBroadcast(vm.envAddress("SENDER"));
        snapshot_ = proxy_.captureMigrationSnapshot();
        vm.stopBroadcast();
    }

    function configureIndependent(Allocation proxy_, Migration.IndependentAllocationInput[] calldata inputs_) external {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.configureIndependentAllocations(inputs_);
        vm.stopBroadcast();
    }

    /// @notice Complete interface-owned inputs include the explicit original wallet; no ownerOf fallback.
    function configureNfts(Allocation proxy_, Migration.NftEntitlementInput[] calldata inputs_) external {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.configureNftEntitlements(inputs_);
        vm.stopBroadcast();
    }

    function independentIssue(Allocation proxy_, Migration.IndependentIssuanceRequest[] calldata requests_)
        external returns (uint256[] memory ids_)
    {
        vm.startBroadcast(vm.envAddress("SENDER"));
        ids_ = proxy_.issueIndependentAllocations(requests_);
        vm.stopBroadcast();
    }

    function configureWeightedLiquid(Allocation proxy_, Migration.WeightedLiquidEntitlementInput[] calldata inputs_)
        external
    {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.configureWeightedLiquidEntitlements(inputs_);
        vm.stopBroadcast();
    }

    function surrenderWeightedLiquid(Migration proxy_, bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_)
    {
        vm.startBroadcast(vm.envAddress("SENDER"));
        (bondTokenId_, credit_) = proxy_.surrenderMigrationWeightedLiquid(originalId_, amount_, minimum_, deadline_);
        vm.stopBroadcast();
    }

    function activate(Allocation proxy_) external {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.activateMigration();
        vm.stopBroadcast();
    }

    function configureWeightedSy(Allocation proxy_, Migration.WeightedSyEntitlementInput[] calldata inputs_) external {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.configureWeightedSyEntitlements(inputs_);
        vm.stopBroadcast();
    }

    function surrenderWeightedSy(Migration proxy_, bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_)
    {
        vm.startBroadcast(vm.envAddress("SENDER"));
        (bondTokenId_, credit_) = proxy_.surrenderMigrationWeightedSy(originalId_, amount_, minimum_, deadline_);
        vm.stopBroadcast();
    }

    function configureDtfCustodySe(Allocation proxy_, Migration.DtfCustodySeEntitlementInput[] calldata inputs_) external {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.configureDtfCustodySeEntitlements(inputs_);
        vm.stopBroadcast();
    }

    function surrenderDtfCustodySe(Migration proxy_, bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_)
    {
        vm.startBroadcast(vm.envAddress("SENDER"));
        (bondTokenId_, credit_) = proxy_.surrenderMigrationDtfCustodySe(originalId_, amount_, minimum_, deadline_);
        vm.stopBroadcast();
    }

    function configureClaimVault(Allocation proxy_, Migration.ClaimVaultEntitlementInput[] calldata inputs_) external {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.configureClaimVaultEntitlements(inputs_);
        vm.stopBroadcast();
    }

    function surrenderClaimVault(Migration proxy_, bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_)
    {
        vm.startBroadcast(vm.envAddress("SENDER"));
        (bondTokenId_, credit_) = proxy_.surrenderMigrationClaimVault(originalId_, amount_, minimum_, deadline_);
        vm.stopBroadcast();
    }

    function configureWeightedReceipt(Allocation proxy_, Migration.WeightedReceiptEntitlementInput[] calldata inputs_)
        external
    {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.configureWeightedReceiptEntitlements(inputs_);
        vm.stopBroadcast();
    }

    /// @notice amount_ is native9 WS; configuration and consumed units are eligible ownership gons.
    function surrenderWeightedReceipt(
        Migration proxy_, bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_
    ) external returns (uint256 bondTokenId_, uint256 credit_) {
        vm.startBroadcast(vm.envAddress("SENDER"));
        (bondTokenId_, credit_) = proxy_.surrenderMigrationWeightedReceipt(originalId_, amount_, minimum_, deadline_);
        vm.stopBroadcast();
    }

    function configureEarlierReceipt(Allocation proxy_, Migration.EarlierReceiptEntitlementInput[] calldata inputs_)
        external
    {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.configureEarlierReceiptEntitlements(inputs_);
        vm.stopBroadcast();
    }

    /// @notice Displayed native18 approval/pull; Q/q/B use exact internal ER shares.
    function surrenderEarlierReceipt(
        Migration proxy_, bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_
    ) external returns (uint256 bondTokenId_, uint256 credit_) {
        vm.startBroadcast(vm.envAddress("SENDER"));
        (bondTokenId_, credit_) = proxy_.surrenderMigrationEarlierReceipt(originalId_, amount_, minimum_, deadline_);
        vm.stopBroadcast();
    }

    /// @notice Genuine paid ordinary purchase, with explicit operator amounts and duration.
    function ownerFirstBond(Migration proxy_, IERC20 token_, uint256 amount_, uint256 duration_, uint256 deadline_)
        external returns (uint256 bondId_, uint256 lpOut_)
    {
        address sender_ = vm.envAddress("SENDER");
        vm.startBroadcast(sender_);
        require(token_.approve(address(proxy_), amount_), "purchase approval");
        (bondId_, lpOut_) = proxy_.bond(token_, amount_, duration_, sender_, false, deadline_);
        vm.stopBroadcast();
    }

    function harvest(Recovery proxy_, Recovery.Step[] calldata steps_, uint256 deadline_) external {
        vm.startBroadcast(vm.envAddress("SENDER"));
        proxy_.recoverMigrationNfts(steps_, deadline_);
        vm.stopBroadcast();
    }
}
