// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationDFPkg as Package} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationSYDFPkg as SyPackage} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSYDFPkg.sol";
import {IUniswapV4DetfMigration as Migration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/IDETFNFTVaultDFPkg.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {ERC20} from "@crane/contracts/external/openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bond} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IUniswapV4DetfMigrationSY as SY} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSY.sol";
import {IUniswapV4DetfMigrationAllocation as Allocation} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRewardTokenDFPkg as RewardPackage} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";

/// @notice Real registered construction boundaries. Mined cold-transaction receipts are a separate witness.
contract MigrationDeploymentGasTest is TestBase_UniswapV4DetfMigration {
    event ConstructionGas(address indexed parent, uint256 preparation, uint256 finalization);

    function test_twoDistinctPreparedParentsFitBoundedCalls() public {
        for (uint256 i_; i_ < 2; ++i_) {
            address owner_ = address(uint160(0xA100 + i_));
            Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(owner_));
            Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
            uint256 start_ = gasleft();
            (bool prepared_, bytes memory preparation_) = address(migrationPkg).call{gas: 32_000_000}(
                abi.encodeCall(Package.prepareSyChildren, (args_))
            );
            uint256 preparationGas_ = start_ - gasleft();
            assertTrue(prepared_, "bounded SY preparation");
            (address raw_, address staked_) = abi.decode(preparation_, (address, address));
            assertEq(c_.parent.code.length, 0);
            assertEq(IERC20(raw_).totalSupply(), 0);
            assertEq(IERC20(staked_).totalSupply(), 0);
            start_ = gasleft();
            (bool completed_, bytes memory completion_) = address(migrationPkg).call{gas: 32_000_000}(
                abi.encodeCall(Package.deployVault, (args_))
            );
            uint256 finalGas_ = start_ - gasleft();
            assertTrue(completed_, "bounded final parent");
            address parent_ = abi.decode(completion_, (address));
            assertEq(parent_, c_.parent);
            assertEq(Migration(parent_).owner(), owner_);
            assertEq(Migration(parent_).rawSY(), raw_);
            assertEq(Migration(parent_).stakingSY(), staked_);
            assertEq(Migration(parent_).bondNftVault(), c_.bond);
            assertEq(Migration(parent_).rebasingClaimToken(), c_.receipt);
            emit ConstructionGas(parent_, preparationGas_, finalGas_);
        }
    }

    function test_directRegistryCannotConstructWithoutPreparation() public {
        Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(0xA200)));
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Package.MigrationPreparationRequired.selector, c_.constructionId));
        indexedexManager.deployVault(IStandardVaultPkg(address(migrationPkg)), abi.encode(args_));
        assertEq(c_.parent.code.length, 0);
        assertEq(address(diamondPackageFactory.pkgOfAccount(c_.parent)), address(0));
        assertFalse(SyPackage(address(syPkg)).preparation(c_.constructionId).completed);
    }

    function test_explicitChildMetadataAndDirectionalCustomRoutesSurvivePreparation() public {
        Package.PkgArgs memory args_ = _migrationArgs(address(0xA201));
        args_.baseArgs.bondName = "Explicit bond";
        args_.baseArgs.bondSymbol = "EB";
        args_.baseArgs.claimName = "Explicit receipt";
        args_.baseArgs.claimSymbol = "ER";
        args_.baseArgs.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args_.baseArgs.burnRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args_.baseArgs.mintRoutes = new IUniswapV4Detf.IoRoute[](2);
        args_.baseArgs.burnRoutes = new IUniswapV4Detf.IoRoute[](2);
        args_.baseArgs.mintRoutes[0] = IUniswapV4Detf.IoRoute(IERC20(pairB), IStandardExchange(se1));
        args_.baseArgs.mintRoutes[1] = IUniswapV4Detf.IoRoute(IERC20(pairA), IStandardExchange(se0));
        args_.baseArgs.burnRoutes[0] = args_.baseArgs.mintRoutes[1];
        args_.baseArgs.burnRoutes[1] = args_.baseArgs.mintRoutes[0];
        args_ = _prepareMigrationHook(args_);
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        (bool prepared_, bytes memory result_) = address(migrationPkg).call{gas: 32_000_000}(
            abi.encodeCall(Package.prepareSyChildren, (args_))
        );
        assertTrue(prepared_);
        (address raw_, address staking_) = abi.decode(result_, (address, address));
        assertEq(IERC721Metadata(c_.bond).name(), args_.baseArgs.bondName);
        assertEq(IERC721Metadata(c_.bond).symbol(), args_.baseArgs.bondSymbol);
        address[] memory rawIn_ = SY(raw_).getTokensIn();
        address[] memory rawOut_ = SY(raw_).getTokensOut();
        assertEq(rawIn_.length, 3);
        assertEq(rawOut_.length, 3);
        assertEq(rawIn_[0], c_.parent);
        assertEq(rawIn_[1], pairB);
        assertEq(rawIn_[2], pairA);
        assertEq(rawOut_[0], c_.parent);
        assertEq(rawOut_[1], pairA);
        assertEq(rawOut_[2], pairB);
        address[] memory stakingIn_ = SY(staking_).getTokensIn();
        assertEq(stakingIn_.length, 4);
        assertEq(stakingIn_[0], c_.parent);
        assertEq(stakingIn_[1], c_.receipt);
        assertEq(stakingIn_[2], pairB);
        assertEq(stakingIn_[3], pairA);
        (bool completed_,) = address(migrationPkg).call{gas: 32_000_000}(
            abi.encodeCall(Package.deployVault, (args_))
        );
        assertTrue(completed_);
        assertEq(IERC20Metadata(c_.receipt).name(), args_.baseArgs.claimName);
        assertEq(IERC20Metadata(c_.receipt).symbol(), args_.baseArgs.claimSymbol);
        assertEq(Migration(c_.parent).bondNftVault(), c_.bond);
        assertEq(Migration(c_.parent).rawSY(), raw_);
        assertEq(Migration(c_.parent).stakingSY(), staking_);
    }

    function test_predeployedBondAdoptionAndEarlyRoutesCannotBuyRights() public {
        Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(0xA300)));
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        IERC20(pairA).transfer(c_.bond, 17);
        address bond_ = IDETFNFTVaultDFPkg(address(bondNftVaultPkg)).deployVault(
            c_.bondArgs.name, c_.bondArgs.symbol, c_.bondArgs.detf, c_.bondArgs.lpToken
        );
        assertEq(bond_, c_.bond);
        IERC721(bond_).setApprovalForAll(address(0xBEEF), true);
        assertTrue(IERC721(bond_).isApprovedForAll(address(this), address(0xBEEF)));
        assertFalse(IERC721(bond_).isApprovedForAll(args_.owner, address(0xBEEF)));
        _assertBond(bond_, false);
        bytes[] memory calls_ = new bytes[](14);
        calls_[0] = abi.encodeWithSignature("initializeReservedBondNfts(address,address)", address(this), address(this));
        calls_[1] = abi.encodeWithSignature("createFundedPosition(uint256,uint256,address)", 1, 90 days, address(this));
        calls_[2] = abi.encodeCall(Bond.createMigrationPosition, (1, address(this)));
        calls_[3] = abi.encodeWithSignature("claimPrincipal(uint256,address)", 3, address(this));
        calls_[4] = abi.encodeWithSignature("claimRewards(uint256,address)", 3, address(this));
        calls_[5] = abi.encodeWithSignature("claimBond(uint256,address)", 3, address(this));
        calls_[6] = abi.encodeCall(IERC721.transferFrom, (address(this), address(0xBEEF), 3));
        calls_[7] = abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", address(this), address(0xBEEF), 3);
        calls_[8] = abi.encodeWithSignature("safeTransferFrom(address,address,uint256,bytes)", address(this), address(0xBEEF), 3, bytes(""));
        calls_[9] = abi.encodeWithSignature("transferHeldToken(address,address,uint256)", pairA, address(this), 17);
        calls_[10] = abi.encodeWithSignature("donate(address,uint256,uint256,bool,uint256)", pairA, 1, 0, false, block.timestamp);
        calls_[11] = abi.encodeWithSignature("donate(address,address,uint256,uint256,bool,uint256)", address(this), pairA, 1, 0, false, block.timestamp);
        calls_[12] = abi.encodeWithSignature("donateWithPermit2Allowance(address,uint256,uint256,uint256)", pairA, 1, 0, block.timestamp);
        calls_[13] = abi.encodeWithSignature("donateWithPermit2Signature(address,uint256,uint256,uint256,bytes)", pairA, 1, 0, block.timestamp, bytes(""));
        for (uint256 i_; i_ < calls_.length; ++i_) {
            assertNotEq(IDiamondLoupe(bond_).facetAddress(bytes4(calls_[i_])), address(0));
            _reject(bond_, calls_[i_]);
            _assertBond(bond_, false);
        }
        for (uint256 i_; i_ < 4; ++i_) _reject(bond_, abi.encodeCall(IERC721.approve, (address(0xBEEF), i_)));
        assertEq(Bond(bond_).previewDonate(IERC20(pairA), 1), 0);
        assertEq(Bond(bond_).previewDonate(c_.bondArgs.lpToken, 1), 0);
        // The public common initializer can initialize its own package, not this proxy.
        IDiamondFactoryPackage(address(bondNftVaultPkg)).initAccount(abi.encode(c_.bondArgs));
        _reject(address(bondNftVaultPkg), abi.encodeCall(IDiamondFactoryPackage.initAccount, (abi.encode(c_.bondArgs))));
        _reject(bond_, abi.encodeCall(IDiamondFactoryPackage.initAccount, (abi.encode(c_.bondArgs))));
        _reject(bond_, abi.encodeCall(IPostDeployAccountHook.postDeploy, ()));
        _assertBond(bond_, false);
        migrationPkg.prepareSyChildren(args_);
        migrationPkg.prepareSyChildren(args_);
        address parent_ = migrationPkg.deployVault(args_);
        assertEq(Migration(parent_).bondNftVault(), bond_);
        _assertBond(bond_, true);
        assertEq(IERC20(pairA).balanceOf(bond_), 17);
        assertTrue(IERC721(bond_).isApprovedForAll(address(this), address(0xBEEF)));
    }

    function test_bothPreparedSyMoneyRoutesLeaveZeroBackingAndAllowFinalization() public {
        Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(0xA301)));
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        (address raw_, address staked_) = migrationPkg.prepareSyChildren(args_);
        address[2] memory children_ = [raw_, staked_];
        for (uint256 i_; i_ < 2; ++i_) {
            address child_ = children_[i_];
            IERC20(pairA).transfer(child_, 13);
            IERC20(child_).approve(address(0xBEEF), 5);
            bytes[] memory calls_ = new bytes[](8);
            calls_[0] = abi.encodeCall(IERC20.transfer, (address(this), 0));
            calls_[1] = abi.encodeCall(IERC20.transferFrom, (address(this), address(this), 0));
            calls_[2] = abi.encodeWithSignature("deposit(address,address,uint256,uint256)", address(this), pairA, 1, 0);
            calls_[3] = abi.encodeWithSignature("redeem(address,uint256,address,uint256,bool)", address(this), 1, pairA, 0, false);
            calls_[4] = abi.encodeWithSignature("redeem(address,uint256,address,uint256,bool)", address(this), 1, pairA, 0, true);
            calls_[5] = abi.encodeWithSignature("claimRewards(address)", address(this));
            calls_[6] = abi.encodeWithSignature("rewardIndexesCurrent()");
            calls_[7] = abi.encodeCall(SY.claimRewardRemainder, ());
            for (uint256 j_; j_ < calls_.length; ++j_) {
                assertNotEq(IDiamondLoupe(child_).facetAddress(bytes4(calls_[j_])), address(0));
                _reject(child_, calls_[j_]);
                assertEq(IERC20(child_).totalSupply(), 0);
                assertEq(SY(child_).attributedSyGons(), 0);
                assertEq(SY(child_).migrationAccountingPhase(), 0);
            }
            bytes32 slot_ = bytes32(uint256(keccak256("indexedex.detf.standardized.yield")) - 1);
            for (uint256 j_ = 2; j_ < 5; ++j_) assertEq(vm.load(child_, bytes32(uint256(slot_) + j_)), bytes32(0));
            _reject(child_, abi.encodeCall(IDiamondFactoryPackage.initAccount, (abi.encode(c_.rawArgs))));
            _reject(child_, abi.encodeCall(IPostDeployAccountHook.postDeploy, ()));
            assertEq(IERC20(pairA).balanceOf(child_), 13);
        }
        migrationPkg.deployVault(args_);
        assertEq(IERC20(raw_).allowance(address(this), address(0xBEEF)), 5);
        assertEq(IERC20(staked_).allowance(address(this), address(0xBEEF)), 5);
    }

    function test_exactBondAndSyArgumentMutationMatrixRejectsSubstitution() public {
        Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(0xA302)));
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        (address raw_,) = migrationPkg.prepareSyChildren(args_);
        SyPackage sy_ = SyPackage(address(syPkg));
        for (uint256 i_; i_ < 5; ++i_) {
            IDETFNFTVaultDFPkg.PkgArgs memory changed_ = abi.decode(abi.encode(c_.bondArgs), (IDETFNFTVaultDFPkg.PkgArgs));
            address pkg_ = address(bondNftVaultPkg);
            if (i_ == 0) changed_.lpToken = IERC20(pairA);
            if (i_ == 1) changed_.detf = IDetf(detf);
            if (i_ == 2) changed_.name = "different";
            if (i_ == 3) changed_.symbol = "different";
            if (i_ == 4) pkg_ = address(migrationPkg);
            _reject(address(sy_), abi.encodeCall(SyPackage.validateBond, (c_.bond, pkg_, changed_, false, address(0))));
        }
        for (uint256 i_; i_ < 7; ++i_) {
            IDETFSYDFPkg.PkgArgs memory changed_ = abi.decode(abi.encode(c_.rawArgs), (IDETFSYDFPkg.PkgArgs));
            if (i_ == 0) changed_.detf = IERC20(detf);
            if (i_ == 1) changed_.staking = receipt;
            if (i_ == 2) changed_.isStaking = true;
            if (i_ == 3) changed_.name = "different";
            if (i_ == 4) changed_.symbol = "different";
            if (i_ == 5) (changed_.tokensIn[0], changed_.tokensIn[1]) = (changed_.tokensIn[1], changed_.tokensIn[0]);
            if (i_ == 6) (changed_.tokensOut[0], changed_.tokensOut[1]) = (changed_.tokensOut[1], changed_.tokensOut[0]);
            _reject(address(sy_), abi.encodeCall(SyPackage.validateChild, (raw_, changed_)));
            _reject(address(sy_), abi.encodeCall(IDETFSYDFPkg.deployVault, (changed_)));
        }
        _reject(address(sy_), abi.encodeCall(SyPackage.prepare, (args_)));
        _reject(address(sy_), abi.encodeCall(IDiamondFactoryPackage.initAccount, (abi.encode(c_.rawArgs))));
        _reject(address(migrationPkg), abi.encodeCall(IDiamondFactoryPackage.initAccount, (abi.encode(args_))));
        _reject(address(diamondPackageFactory), abi.encodeCall(
            IDiamondPackageCallBackFactory.deploy, (IDiamondFactoryPackage(address(migrationPkg)), abi.encode(args_))
        ));
        vm.prank(owner);
        (bool canonical_,) = address(indexedexManager).call(abi.encodeCall(
            IVaultRegistryDeployment.deployVault, (IStandardVaultPkg(address(migrationPkg)), bytes.concat(abi.encode(args_), bytes32(uint256(1))))
        ));
        assertFalse(canonical_);
        uint256 chain_ = vm.getChainId();
        vm.chainId(chain_ + 1);
        _reject(address(migrationPkg), abi.encodeCall(Package.deployVault, (args_)));
        vm.chainId(chain_);
        Package.PkgArgs memory ownerArgs_ = abi.decode(abi.encode(args_), (Package.PkgArgs));
        ownerArgs_.owner = address(0xBAD);
        _reject(address(migrationPkg), abi.encodeCall(Package.deployVault, (ownerArgs_)));
        assertTrue(sy_.preparation(c_.constructionId).completed);
        migrationPkg.deployVault(args_);
    }

    function test_preparationFailureRollsBackFreshAndPreexistingBondThenRetries() public {
        for (uint256 i_; i_ < 2; ++i_) {
            Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(uint160(0xA310 + i_))));
            Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
            if (i_ == 1) {
                IDETFNFTVaultDFPkg(address(bondNftVaultPkg)).deployVault(
                    c_.bondArgs.name, c_.bondArgs.symbol, c_.bondArgs.detf, c_.bondArgs.lpToken
                );
                IERC20(pairA).transfer(c_.bond, 19);
                IERC721(c_.bond).setApprovalForAll(address(0xBEEF), true);
            }
            _disable(address(syPkg), true);
            vm.expectCall(address(bondNftVaultPkg), abi.encodeCall(IDETFNFTVaultDFPkg.deployVault,
                (c_.bondArgs.name, c_.bondArgs.symbol, c_.bondArgs.detf, c_.bondArgs.lpToken)));
            _reject(address(migrationPkg), abi.encodeCall(Package.prepareSyChildren, (args_)));
            _assertUnprepared(c_);
            if (i_ == 0) {
                assertEq(c_.bond.code.length, 0);
                assertFalse(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(c_.bond));
                assertEq(address(diamondPackageFactory.pkgOfAccount(c_.bond)), address(0));
            } else {
                _assertBond(c_.bond, false);
                assertEq(IERC20(pairA).balanceOf(c_.bond), 19);
                assertTrue(IERC721(c_.bond).isApprovedForAll(address(this), address(0xBEEF)));
            }
            _disable(address(syPkg), false);
            migrationPkg.prepareSyChildren(args_);
            migrationPkg.deployVault(args_);
            _assertBond(c_.bond, true);
        }
    }

    function test_secondSyGasFailureRollsBackAllThreeChildrenAndLock() public {
        Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(0xA312)));
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        vm.expectCall(address(indexedexManager), abi.encodeCall(IVaultRegistryDeployment.deployVault,
            (IStandardVaultPkg(address(syPkg)), abi.encode(c_.stakingArgs))));
        (bool ok_,) = address(migrationPkg).call{gas: 15_000_000}(abi.encodeCall(Package.prepareSyChildren, (args_)));
        assertFalse(ok_);
        _assertUnprepared(c_);
        assertEq(c_.bond.code.length, 0);
        migrationPkg.prepareSyChildren(args_);
        migrationPkg.deployVault(args_);
    }

    function test_finalFailureAfterRolesAndPublicationRestoresCommittedChildren() public {
        for (uint256 i_; i_ < 2; ++i_) {
            Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(uint160(0xA320 + i_))));
            Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
            address reward_ = diamondPackageFactory.calcAddress(
                diamondPackageFactory.pkgOfAccount(migration.migrationSyRewardToken()),
                abi.encode(RewardPackage.PkgArgs(c_.parent, c_.receipt, string.concat(args_.baseArgs.name, " SY Rewards"), "mRT"))
            );
            (address raw_, address staking_) = migrationPkg.prepareSyChildren(args_);
            IERC20(pairA).transfer(c_.bond, 23);
            IERC721(c_.bond).setApprovalForAll(address(0xBEEF), true);
            vm.expectCall(c_.bond, abi.encodeWithSignature("initializeReservedBondNfts(address,address)",
                address(feeCollector), args_.baseArgs.creator));
            if (i_ == 0) {
                _disable(address(syPkg), true);
                _reject(address(migrationPkg), abi.encodeCall(Package.deployVault, (args_)));
                _disable(address(syPkg), false);
            } else {
                vm.expectCall(c_.parent, abi.encodeCall(IStandardVault.vaultConfig, ()));
                (bool ok_,) = address(migrationPkg).call{gas: 25_000_000}(abi.encodeCall(Package.deployVault, (args_)));
                assertFalse(ok_);
            }
            assertEq(c_.parent.code.length, 0);
            assertEq(c_.receipt.code.length, 0);
            assertEq(reward_.code.length, 0);
            assertEq(address(diamondPackageFactory.pkgOfAccount(c_.receipt)), address(0));
            assertEq(address(diamondPackageFactory.pkgOfAccount(reward_)), address(0));
            assertFalse(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(c_.parent));
            assertEq(address(diamondPackageFactory.pkgOfAccount(c_.parent)), address(0));
            _assertBond(c_.bond, false);
            assertGt(raw_.code.length, 0);
            assertGt(staking_.code.length, 0);
            assertTrue(SyPackage(address(syPkg)).preparation(c_.constructionId).completed);
            assertEq(IERC20(pairA).balanceOf(c_.bond), 23);
            assertTrue(IERC721(c_.bond).isApprovedForAll(address(this), address(0xBEEF)));
            address parent_ = migrationPkg.deployVault(args_);
            assertEq(Migration(parent_).migrationSyRewardToken(), reward_);
            _assertBond(c_.bond, true);
        }
    }

    function test_bondAndParentDisableRemainAuthoritativeWithoutConsumingPreparation() public {
        Package.PkgArgs memory args_ = _prepareMigrationHook(_migrationArgs(address(0xA322)));
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        _disable(address(bondNftVaultPkg), true);
        _reject(address(migrationPkg), abi.encodeCall(Package.prepareSyChildren, (args_)));
        _assertUnprepared(c_);
        assertEq(c_.bond.code.length, 0);
        _disable(address(bondNftVaultPkg), false);
        migrationPkg.prepareSyChildren(args_);
        _disable(address(migrationPkg), true);
        _reject(address(migrationPkg), abi.encodeCall(Package.deployVault, (args_)));
        assertEq(c_.parent.code.length, 0);
        _assertBond(c_.bond, false);
        assertTrue(SyPackage(address(syPkg)).preparation(c_.constructionId).completed);
        _disable(address(migrationPkg), false);
        migrationPkg.deployVault(args_);
        _assertBond(c_.bond, true);
    }

    function test_alternativeHooksDoNotReserveParentInEitherPreparationOrder() public {
        for (uint256 i_; i_ < 2; ++i_) {
            Package.PkgArgs memory a_ = _prepareMigrationHook(_migrationArgs(address(uint160(0xA330 + i_))));
            Package.PkgArgs memory b_ = _prepareMigrationHookWithWeight(_migrationArgs(a_.owner), 6e17);
            Package.SyConstruction memory ca_ = migrationPkg.syConstruction(a_);
            Package.SyConstruction memory cb_ = migrationPkg.syConstruction(b_);
            assertEq(ca_.parent, cb_.parent);
            assertNotEq(ca_.bond, cb_.bond);
            assertNotEq(ca_.receipt, cb_.receipt);
            assertNotEq(ca_.constructionId, cb_.constructionId);
            migrationPkg.prepareSyChildren(i_ == 0 ? a_ : b_);
            migrationPkg.prepareSyChildren(i_ == 0 ? b_ : a_);
            // The first preparer cannot veto finalizing the other full payload.
            Package.PkgArgs memory winner_ = i_ == 0 ? b_ : a_;
            Package.PkgArgs memory unused_ = i_ == 0 ? a_ : b_;
            address parent_ = migrationPkg.deployVault(winner_);
            _reject(address(migrationPkg), abi.encodeCall(Package.deployVault, (unused_)));
            vm.prank(owner);
            assertEq(indexedexManager.deployVault(IStandardVaultPkg(address(migrationPkg)), abi.encode(unused_)), parent_);
            assertEq(keccak256(diamondPackageFactory.pkgArgsOfAccount(parent_)), keccak256(abi.encode(winner_)));
            assertEq(Migration(parent_).hook(), winner_.baseArgs.hook);
            _reject(address(migrationPkg), abi.encodeCall(Package.prepareSyChildren, (unused_)));
            _assertBond(i_ == 0 ? ca_.bond : cb_.bond, false);
        }
    }

    function test_packageFactoryAndCallbackRoutesCannotRestoreActivatedParent() public {
        _fundAndCapture();
        _buyOwnerFirstBond();
        Package.PkgArgs memory args_ = _migrationArgs(migrationOwner);
        args_.baseArgs.hook = migration.hook();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        assertEq(migrationPkg.deployVault(args_), detf);
        vm.prank(owner);
        assertEq(indexedexManager.deployVault(IStandardVaultPkg(address(migrationPkg)), abi.encode(args_)), detf);
        assertEq(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(migrationPkg)), abi.encode(args_)), detf);
        _reject(address(migrationPkg), abi.encodeCall(Package.prepareSyChildren, (args_)));
        _reject(address(migrationPkg), abi.encodeCall(IDiamondFactoryPackage.postDeploy, (detf)));
        _reject(address(migrationPkg), abi.encodeCall(IDiamondFactoryPackage.updatePkg, (detf, abi.encode(args_))));
        _reject(address(migrationPkg), abi.encodeCall(IDiamondFactoryPackage.initAccount, (abi.encode(args_))));
        _reject(address(diamondPackageFactory), abi.encodeWithSignature("initAccount(address,bytes)", address(migrationPkg), abi.encode(args_)));
        _reject(detf, abi.encodeCall(IPostDeployAccountHook.postDeploy, ()));
        _reject(detf, abi.encodeCall(IDiamondFactoryPackage.initAccount, (abi.encode(args_))));
        bytes4[16] memory removed_ = [Allocation.bootstrapMigrationReserve.selector, Allocation.captureMigrationSnapshot.selector,
            Allocation.configureIndependentAllocations.selector, Allocation.issueIndependentAllocations.selector,
            Allocation.configureNftEntitlements.selector, Allocation.activateMigration.selector,
            Allocation.configureWeightedSyEntitlements.selector, Allocation.configureDtfCustodySeEntitlements.selector,
            Allocation.configureClaimedSyEntitlements.selector, Allocation.configureClaimVaultEntitlements.selector,
            Allocation.configureWeightedReceiptEntitlements.selector, Allocation.configureEarlierReceiptEntitlements.selector,
            Allocation.configureWeightedLiquidEntitlements.selector, Allocation.configureEarlierLiquidEntitlements.selector,
            Allocation.configureHeldSeLpEntitlements.selector, Allocation.configureNftContributionEntitlements.selector];
        for (uint256 i_; i_ < removed_.length; ++i_) assertEq(IDiamondLoupe(detf).facetAddress(removed_[i_]), address(0));
        assertTrue(migration.migrationActivated());
    }

    function _reject(address target_, bytes memory data_) private {
        (bool ok_,) = target_.call(data_);
        assertFalse(ok_, "forbidden operation succeeded");
    }

    function _disable(address package_, bool disabled_) private {
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(package_, disabled_);
    }

    function _assertUnprepared(Package.SyConstruction memory c_) private view {
        SyPackage sy_ = SyPackage(address(syPkg));
        assertFalse(sy_.preparation(c_.constructionId).completed);
        assertEq(sy_.preparation(c_.constructionId).parent, address(0));
        assertEq(sy_.authorizedChild(keccak256(abi.encode(c_.rawArgs))), address(0));
        assertEq(sy_.authorizedChild(keccak256(abi.encode(c_.stakingArgs))), address(0));
        address raw_ = diamondPackageFactory.calcAddress(IDiamondFactoryPackage(address(syPkg)), abi.encode(c_.rawArgs));
        address staking_ = diamondPackageFactory.calcAddress(IDiamondFactoryPackage(address(syPkg)), abi.encode(c_.stakingArgs));
        assertEq(raw_.code.length, 0);
        assertEq(staking_.code.length, 0);
        assertFalse(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(raw_));
        assertFalse(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(staking_));
        assertEq(address(diamondPackageFactory.pkgOfAccount(raw_)), address(0));
        assertEq(address(diamondPackageFactory.pkgOfAccount(staking_)), address(0));
    }

    function _assertBond(address bond_, bool reserved_) private view {
        assertEq(Bond(bond_).reservedBondNftsWired(), reserved_);
        assertEq(Bond(bond_).attributedBondGons(), 0);
        assertEq(Bond(bond_).migrationAccountingPhase(), 0);
        assertEq(uint256(vm.load(bond_, bytes32(uint256(keccak256(abi.encode("eip.erc.721"))) - 1))), reserved_ ? 3 : 0);
        assertEq(IERC721(bond_).ownerOf(3), address(0));
        for (uint256 i_; i_ < 4; ++i_) {
            if (!reserved_) assertEq(IERC721(bond_).ownerOf(i_), address(0));
            assertFalse(Bond(bond_).isMigrationPosition(i_));
            uint256 slot_ = uint256(keccak256("indexedex.detf.funded.bonds")) - 1;
            uint256 position_ = uint256(keccak256(abi.encode(i_, slot_ + 3)));
            for (uint256 j_; j_ < 5; ++j_) assertEq(vm.load(bond_, bytes32(position_ + j_)), bytes32(0));
        }
        assertEq(IDiamondLoupe(bond_).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
    }
}

/// @notice Non-SUT external currency. Real V3 SE preview reads exercise static callback boundaries.
contract MigrationConstructionCallbackToken is ERC20 {
    address private watchedVault;
    address private target;
    bytes private payload;
    bool private forceFailure;
    error ConstructionReadReached();
    constructor() ERC20("Construction callback currency", "CALLBACK") {}
    function mint(address recipient_, uint256 amount_) external { _mint(recipient_, amount_); }
    function arm(address vault_, address target_, bytes calldata payload_, bool force_) external {
        watchedVault = vault_; target = target_; payload = payload_; forceFailure = force_;
    }
    function balanceOf(address account_) public view override returns (uint256) {
        if (account_ == watchedVault && target != address(0)) this.probe();
        return super.balanceOf(account_);
    }
    function probe() external view {
        if (forceFailure) revert ConstructionReadReached();
        (bool ok_,) = target.staticcall{gas: 100_000}(payload);
        require(!ok_, "construction reentry succeeded");
    }
}

contract MigrationConstructionCallbackTest is TestBase_UniswapV4DetfMigration {
    function _deployContributionFixture() internal override returns (address) {
        return create3Factory.create3WithArgs(
            type(MigrationConstructionCallbackToken).creationCode, "", keccak256("migration.construction.callback")
        );
    }

    function test_realCustomRouteCallbacksCannotReenterEitherConstructionBoundary() public {
        Package.PkgArgs memory args_ = _migrationArgs(address(0xCA11));
        args_.baseArgs.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args_.baseArgs.mintRoutes = new IUniswapV4Detf.IoRoute[](1);
        args_.baseArgs.mintRoutes[0] = IUniswapV4Detf.IoRoute(IERC20(pairB), IStandardExchange(se1));
        args_ = _prepareMigrationHook(args_);
        Package.SyConstruction memory c_ = migrationPkg.syConstruction(args_);
        MigrationConstructionCallbackToken token_ = MigrationConstructionCallbackToken(pairB);
        bytes memory preparation_ = abi.encodeCall(Package.prepareSyChildren, (args_));
        token_.arm(se1, address(migrationPkg), preparation_, true);
        vm.expectRevert(MigrationConstructionCallbackToken.ConstructionReadReached.selector);
        migrationPkg.prepareSyChildren(args_);
        assertFalse(SyPackage(address(syPkg)).preparation(c_.constructionId).completed);
        assertEq(c_.bond.code.length, 0);
        token_.arm(se1, address(migrationPkg), preparation_, false);
        vm.expectCall(pairB, abi.encodeCall(MigrationConstructionCallbackToken.probe, ()));
        migrationPkg.prepareSyChildren(args_);
        assertTrue(SyPackage(address(syPkg)).preparation(c_.constructionId).completed);
        assertFalse(Bond(c_.bond).reservedBondNftsWired());
        bytes memory finalization_ = abi.encodeCall(Package.deployVault, (args_));
        token_.arm(se1, address(migrationPkg), finalization_, true);
        vm.expectRevert(MigrationConstructionCallbackToken.ConstructionReadReached.selector);
        migrationPkg.deployVault(args_);
        assertEq(c_.parent.code.length, 0);
        assertFalse(Bond(c_.bond).reservedBondNftsWired());
        token_.arm(se1, address(migrationPkg), finalization_, false);
        vm.expectCall(pairB, abi.encodeCall(MigrationConstructionCallbackToken.probe, ()));
        address parent_ = migrationPkg.deployVault(args_);
        assertEq(parent_, c_.parent);
        assertEq(Migration(parent_).owner(), args_.owner);
        assertTrue(Bond(c_.bond).reservedBondNftsWired());
        assertEq(IERC20(parent_).totalSupply(), 0);
        assertEq(Bond(c_.bond).attributedBondGons(), 0);
    }
}
