// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationNftForkBase} from "./MigrationNftForkBase.sol";
import {IUniswapV4DetfMigrationDFPkg as Package} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigration as Migration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bond} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";

/// @notice Pinned real-registry two-instance proof; cold transaction receipts remain separately recorded.
contract MigrationDeploymentGasForkTest is MigrationNftForkBase {
    function test_pinnedTwoInstancesPrepareUnreservedBondsAndCompleteWithinBound() public {
        address previous_;
        for (uint256 i_; i_ < 2; ++i_) {
            Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(uint160(0xF100 + i_))));
            Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
            (bool prepared_, bytes memory children_) = address(migrationPkg).call{gas: 32_000_000}(
                abi.encodeCall(Package.prepareSyChildren, (args_))
            );
            assertTrue(prepared_);
            (address raw_, address staking_) = abi.decode(children_, (address, address));
            assertEq(c_.parent.code.length, 0);
            assertEq(c_.receipt.code.length, 0);
            assertFalse(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(c_.parent));
            assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(c_.bond));
            Bond bond_ = Bond(c_.bond);
            assertEq(bond_.detf(), c_.parent);
            assertEq(address(bond_.lpToken()), args_.baseArgs.hook);
            assertFalse(bond_.reservedBondNftsWired());
            assertEq(bond_.attributedBondGons(), 0);
            assertEq(bond_.migrationAccountingPhase(), 0);
            bytes32 nextIdSlot_ = bytes32(uint256(keccak256(abi.encode("eip.erc.721"))) - 1);
            assertEq(vm.load(c_.bond, nextIdSlot_), bytes32(0));
            for (uint256 j_; j_ < 4; ++j_) {
                assertEq(bond_.ownerOf(j_), address(0));
                assertFalse(bond_.isMigrationPosition(j_));
            }
            (bool completed_, bytes memory result_) = address(migrationPkg).call{gas: 32_000_000}(
                abi.encodeCall(Package.deployVault, (args_))
            );
            assertTrue(completed_);
            address parent_ = abi.decode(result_, (address));
            assertNotEq(parent_, previous_);
            previous_ = parent_;
            assertEq(parent_, c_.parent);
            assertEq(Migration(parent_).owner(), args_.owner);
            assertEq(Migration(parent_).hook(), args_.baseArgs.hook);
            assertEq(Migration(parent_).bondNftVault(), c_.bond);
            assertEq(Migration(parent_).rebasingClaimToken(), c_.receipt);
            assertEq(Migration(parent_).rawSY(), raw_);
            assertEq(Migration(parent_).stakingSY(), staking_);
            assertTrue(bond_.reservedBondNftsWired());
            assertEq(uint256(vm.load(c_.bond, nextIdSlot_)), 3);
            assertEq(bond_.ownerOf(3), address(0));
            assertEq(IERC20(parent_).totalSupply(), 0);
            assertEq(IERC20(raw_).totalSupply(), 0);
            assertEq(IERC20(staking_).totalSupply(), 0);
        }
    }
}
