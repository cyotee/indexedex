// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationCoreLocalQA} from "./MigrationCoreLocalQA.s.sol";
import {IUniswapV4DetfMigrationDFPkg as Package} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigration as Migration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSYDFPkg as SyPackage} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSYDFPkg.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {console2} from "forge-std/console2.sol";

/// @notice Current-bytecode local witness. Submit every generated transaction with gas <= 32,000,000.
/// @dev Uses the real CREATE3/manager TestBase, not historical infrastructure artifacts.
/// Contribution currencies are external fixtures; parent, hook and five children are production code.
contract MigrationDeploymentGasResumedQA is MigrationCoreLocalQA {
    event DeploymentWitness(address packageAddress, address factory, address registry,
        address parent, address initialOwner, bytes arguments);

    function run() external {
        require(block.chainid == 4663 && tx.origin == DEV, "owned local witness");
        localBroadcast = true;
        payer = DEV;
        migrationOwner = DEV;
        vm.startBroadcast(DEV);
        _localInfrastructure();
        _migrationEnvironment();
        Package.PkgArgs memory first_ = _migrationArgs(DEV);
        first_.baseArgs.hook = Migration(detf).hook();
        _assertCompleted(detf, first_);
        Package.PkgArgs memory second_ = _prepareMigrationHook(_migrationArgs(RECEIVER));
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(second_);
        migrationPkg.prepareSyChildren(second_);
        require(c_.parent.code.length == 0 && c_.receipt.code.length == 0, "no staged parent or receipt");
        address secondParent_ = migrationPkg.deployVault(second_);
        require(secondParent_ != detf, "distinct parent");
        _assertCompleted(secondParent_, second_);
        _fundAndCapture();
        _operationSamples();
        vm.stopBroadcast();
    }

    /// @dev Complete originals remain intact. The two axes are measured separately.
    function _operationSamples() internal {
        uint256[5] memory sizes_ = [uint256(1), 8, 16, 32, 64];
        for (uint256 population_; population_ < 2; ++population_) {
            if (population_ == 1) {
                for (uint256 chunk_; chunk_ < 8; ++chunk_) {
                    Migration.IndependentAllocationInput[] memory background_ = _gasRows(16, 1, 100000 + chunk_ * 16);
                    _migrationStart();
                    allocation.configureIndependentAllocations(background_, pricingId);
                    _migrationStop();
                }
            }
            for (uint256 axis_; axis_ < 2; ++axis_) {
                for (uint256 i_; i_ < sizes_.length; ++i_) {
                    // Earlier selected rows remain and are counted by the receipt recorder.
                    uint256 selected_ = axis_ == 0 ? sizes_[i_] : 1;
                    uint256 originals_ = axis_ == 0 ? 1 : sizes_[i_];
                    uint256 seed_ = 1000 + population_ * 20000 + axis_ * 10000 + i_ * 100;
                    Migration.IndependentAllocationInput[] memory rows_ = _gasRows(selected_, originals_, seed_);
                    _migrationStart();
                    allocation.configureIndependentAllocations(rows_, pricingId);
                    _migrationStop();
                    console2.log("LOAD_GAS", vm.lastCallGas().gasTotalUsed);
                    // The measured 64-recipient issuance exceeds the pinned target ceiling.
                    // Keep that full boundary in the hermetic matrix, never broadcast it.
                    if (localBroadcast && selected_ > 32) continue;
                    Migration.IndependentIssuanceRequest[] memory requests_ = new Migration.IndependentIssuanceRequest[](selected_);
                    for (uint256 j_; j_ < selected_; ++j_) {
                        requests_[j_] = Migration.IndependentIssuanceRequest(
                            rows_[j_].recipient, migration.independentAllocation(rows_[j_].recipient).configurationId
                        );
                    }
                    _migrationStart();
                    uint256[] memory ids_ = allocation.issueIndependentAllocations(requests_);
                    _migrationStop();
                    console2.log("ISSUE_GAS", vm.lastCallGas().gasTotalUsed);
                    for (uint256 j_; j_ < selected_; ++j_) {
                        Migration.IndependentAllocation memory config_ = migration.independentAllocation(rows_[j_].recipient);
                        require(config_.entitlements.length == originals_, "complete original array");
                        require(migration.independentIssuance(rows_[j_].recipient).credit == config_.totalCredit, "exact issued credit");
                        require(bonds.positionOf(ids_[j_]).principal == config_.totalCredit, "funded principal");
                    }
                }
            }
        }
    }

    function _gasRows(uint256 selected_, uint256 originals_, uint256 seed_)
        internal pure returns (Migration.IndependentAllocationInput[] memory rows_)
    {
        rows_ = new Migration.IndependentAllocationInput[](selected_);
        for (uint256 i_; i_ < selected_; ++i_) {
            rows_[i_].recipient = address(uint160(0x100000 + seed_ + i_));
            rows_[i_].evidenceId = keccak256("synthetic operation gas fixture; no historical allocation");
            rows_[i_].entitlements = new Migration.OriginalEntitlement[](originals_);
            for (uint256 j_; j_ < originals_; ++j_) {
                rows_[i_].entitlements[j_] = Migration.OriginalEntitlement(
                    keccak256(abi.encode("gas original", seed_ + i_, j_)), 1e12, 1e12, bytes32("gas fixture")
                );
            }
        }
    }

    function _assertCompleted(address parent_, Package.PkgArgs memory args_) private {
        Migration p_ = Migration(parent_);
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        SyPackage.Preparation memory prepared_ = SyPackage(migrationPkg.syPackage()).preparation(c_.constructionId);
        require(prepared_.completed && c_.parent == parent_ && p_.owner() == args_.owner, "completed binding");
        require(p_.hook() == args_.baseArgs.hook && p_.bondNftVault() == c_.bond
            && p_.rebasingClaimToken() == c_.receipt && p_.rawSY() == prepared_.rawSy
            && p_.stakingSY() == prepared_.stakingSy, "fixed children");
        require(!p_.migrationActivated() && IERC20(parent_).totalSupply() == 0, "inert initial parent");
        emit DeploymentWitness(address(migrationPkg), address(diamondPackageFactory), address(indexedexManager),
            parent_, args_.owner, abi.encode(args_));
    }
}
