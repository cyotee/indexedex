// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationCoreLocalQA} from "./MigrationCoreLocalQA.s.sol";
import {IUniswapV4DetfMigrationDFPkg as Package} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigration as Migration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSYDFPkg as SyPackage} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSYDFPkg.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

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
        vm.stopBroadcast();
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
