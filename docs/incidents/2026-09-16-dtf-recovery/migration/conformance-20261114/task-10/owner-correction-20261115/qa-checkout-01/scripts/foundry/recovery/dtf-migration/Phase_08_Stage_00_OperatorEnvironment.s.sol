// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationCoreLocalQA} from "./MigrationCoreLocalQA.s.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {UniswapV4DetfProductionSeDeployLib as SeLib}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultDFPkg as V3Package}
    from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {IUniswapV4DetfMigrationDFPkg as MigrationPackage}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as HookPackage}
    from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_FactoryService as HookFactory}
    from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";

/// @notice Synthetic local infrastructure only. The CLI separately deploys the real parent.
/// @dev Real DTF must already have been transferred by an actual holder on the owned fork.
contract Phase_08_Stage_00_OperatorEnvironment is MigrationCoreLocalQA {
    address internal constant ORIGINAL_DTF = 0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01;

    function prepareEnvironment() external {
        require(block.chainid == 4663 && tx.origin == DEV, "owned rehearsal identity");
        require(IERC20(ORIGINAL_DTF).balanceOf(DEV) >= 10000 ether, "real holder-funded DTF");
        localBroadcast = true;
        payer = DEV;
        migrationOwner = DEV;
        vm.startBroadcast(DEV);
        _localInfrastructure();
        pairA = create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory,
                "lib/crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol:WETH9"),
            "", keccak256("migration.weth")
        );
        pairB = ORIGINAL_DTF;
        address rate_ = _deployRateFixture();
        IWETH(pairA).deposit{value: 10000 ether}();
        SimpleMintableERC20(rate_).mint(DEV, 20000 ether);
        pm = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(DEV), keccak256("migration.poolmanager")
        ));
        IUniswapV3Factory factory_ = IUniswapV3Factory(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory,
                "lib/crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol:UniswapV3Factory"),
            "", keccak256("migration.v3")
        ));
        V3Package v3_ = _migrationV3Package(factory_);
        se0 = address(SeLib.createUniv3PoolOneToOne(factory_, pairA, rate_, 3000));
        se1 = address(SeLib.createUniv3PoolOneToOne(factory_, pairB, rate_, 3000));
        _seedMigrationPool(SeLibPool(se0), bytes32("A"));
        _seedMigrationPool(SeLibPool(se1), bytes32("B"));
        se0 = v3_.deployVault(SeLibPool(se0));
        se1 = v3_.deployVault(SeLibPool(se1));
        _activateMigrationSe(se0, pairA, rate_);
        _activateMigrationSe(se1, pairB, rate_);
        _migrationHookPackage();
        _migrationPackages();
        MigrationPackage.PkgArgs memory args_ = _migrationArgs(DEV);
        args_.baseArgs.name = string.concat(args_.baseArgs.name, " / ",
            vm.envOr("OPERATOR_REHEARSAL_SCENARIO", string("primary")));
        address predicted_ = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(migrationPkg)), abi.encode(args_)
        );
        args_.baseArgs.hook = _prepareHook(predicted_);
        vm.stopBroadcast();
        // This call is simulation-only: it establishes exact predicted runtime and
        // installed facets without recording a deployment transaction in this stage.
        migrationPkg.prepareSyChildren(args_);
        address simulated_ = migrationPkg.deployVault(args_);
        require(simulated_ == predicted_, "registry prediction");
        string memory key_ = "operator";
        vm.serializeAddress(key_, "proxy", predicted_);
        vm.serializeAddress(key_, "registry", address(indexedexManager));
        vm.serializeAddress(key_, "package", address(migrationPkg));
        vm.serializeAddress(key_, "pairToken", pairB);
        vm.serializeAddress(key_, "weth", pairA);
        vm.serializeBytes(key_, "arguments", abi.encode(args_));
        vm.serializeBytes32(key_, "proxyCodeHash", predicted_.codehash);
        IDiamondLoupe.Facet[] memory facets_ = IDiamondLoupe(predicted_).facets();
        address[] memory addresses_ = new address[](facets_.length);
        for (uint256 i_; i_ < facets_.length; ++i_) addresses_[i_] = facets_[i_].facetAddress;
        string memory output_ = vm.serializeAddress(key_, "facets", addresses_);
        vm.writeJson(output_, vm.envString("OPERATOR_ENVIRONMENT_OUTPUT"));
    }

    function _prepareHook(address predicted_) private returns (address) {
        address[] memory tokens_ = new address[](3);
        tokens_[0] = predicted_; tokens_[1] = pairA; tokens_[2] = pairB;
        _sortInPlace(tokens_);
        uint256[] memory weights_ = new uint256[](3);
        address[] memory exchanges_ = new address[](3);
        for (uint256 i_; i_ < 3; ++i_) {
            weights_[i_] = tokens_[i_] == predicted_ ? 4e17 : 3e17;
            exchanges_[i_] = tokens_[i_] == predicted_ ? address(0) : tokens_[i_] == pairA ? se0 : se1;
        }
        HookPackage.PkgArgs memory args_ = HookPackage.PkgArgs(
            address(pm), address(indexedexManager), 3, tokens_, weights_, exchanges_,
            RateProviderFixtureLib.providersFor(create3Factory, diamondPackageFactory, tokens_, exchanges_),
            HookPkgArgsDecimalsLib.tokenDecimals(tokens_, predicted_), HookPkgArgsDecimalsLib.seDecimals(exchanges_),
            true, predicted_
        );
        address hook_ = weightedHookPkg.deployVault(args_, HookFactory.findMineNonce(hookFactory, weightedHookPkg, args_));
        IUniswapV4HookStagedPairInit init_ = IUniswapV4HookStagedPairInit(hook_);
        init_.deployPair(tokens_[0], tokens_[1]);
        init_.deployPair(tokens_[0], tokens_[2]);
        init_.deployPair(tokens_[1], tokens_[2]);
        require(init_.finalizeInitialization(), "hook initialized");
        return hook_;
    }
}

import {IUniswapV3Pool as SeLibPool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
