// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {LaunchState} from "scripts/foundry/anvil_robinhood_main/LaunchState.sol";
import {Phase_06_Stage_07_UniswapV4DetfPkg} from "scripts/foundry/anvil_robinhood_main/Phase_06_Stage_07_UniswapV4DetfPkg.sol";
import {UniswapV4Detf_Pkg_FactoryService} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {
    IUniswapV4DetfSelfCall
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4DetfSelfCall.sol";
import {UniswapV4DetfRepo} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {DETFFundedStakingArtifacts} from "contracts/test/bases/DETFFundedStakingArtifacts.sol";

/// @notice Real CREATE3 facets and manager-deployed package must satisfy size and routing gates.
contract UniswapV4Detf_FacetPackaging is TestBase_UniswapV4Detf, DETFFundedStakingArtifacts {
    LaunchState private releaseState;

    function test_releaseStage_currentDependenciesResolveCurrentPackage() public {
        _setReleaseState();
        this.executeReleaseStage();
        assertEq(releaseState.uniV4DetfPkg, address(detfPkg), "launch uses current component set");
        this.executeReleaseStage();
        assertEq(releaseState.uniV4DetfPkg, address(detfPkg), "repeated launch reuses current release");
    }

    function test_releaseStage_wrongDependencyPackageRejected() public {
        _setReleaseState();
        releaseState.bondNftVaultPkg = address(rebasingClaimTokenPkg);
        vm.expectRevert(bytes("Phase 06-07: wrong dependency package"));
        this.executeReleaseStage();
        assertEq(releaseState.uniV4DetfPkg, address(0), "release not recorded");
    }

    function test_releaseStage_wrongDependencyImplementationRejected() public {
        _setReleaseState();
        IRebasingClaimTokenDFPkg.PkgInit memory init = IRebasingClaimTokenDFPkg.PkgInit({
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            rebasingClaimTokenFacet: erc20Facet,
            diamondFactory: diamondPackageFactory
        });
        releaseState.rebasingClaimTokenPkg = address(DetfPkgFactoryService.deployRebasingClaimTokenDFPkg(
            create3Factory, init
        ));
        vm.expectRevert(bytes("Phase 06-07: stale dependency facet; run 06-01 and 06-02"));
        this.executeReleaseStage();
        assertEq(releaseState.uniV4DetfPkg, address(0), "release not recorded");
    }

    function executeReleaseStage() external {
        vm.startPrank(owner);
        Phase_06_Stage_07_UniswapV4DetfPkg.execute(releaseState);
        vm.stopPrank();
    }

    function _setReleaseState() private {
        IOperable(address(create3Factory)).setOperator(owner, true);
        releaseState.create3Factory = create3Factory;
        releaseState.indexedexManager = indexedexManager;
        releaseState.erc20Facet = erc20Facet;
        releaseState.erc5267Facet = erc5267Facet;
        releaseState.erc2612Facet = erc2612Facet;
        releaseState.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        releaseState.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        releaseState.bondNftVaultPkg = address(bondNftVaultPkg);
        releaseState.rebasingClaimTokenPkg = address(rebasingClaimTokenPkg);
    }

    /// @notice Existing type-name deployments cannot shadow the current claim implementation.
    function test_releaseSalt_legacyFacetDoesNotShadowCurrentFacet() public {
        string memory artifact = "RebasingClaimTokenFacet.sol:RebasingClaimTokenFacet";
        IFacet legacy = create3Factory.deployFacet(
            vm.getCode("ERC20Facet.sol:ERC20Facet"), keccak256(abi.encode("RebasingClaimTokenFacet"))
        );
        assertTrue(address(legacy).codehash != keccak256(vm.getDeployedCode(artifact)), "occupied slot has different code");
        IFacet current = DetfFacetFactoryService.deployRebasingClaimTokenFacet(create3Factory);
        assertTrue(address(current) != address(legacy), "release does not reuse the legacy salt");
        assertEq(address(current).code, vm.getDeployedCode(artifact), "current implementation installed");
        assertEq(
            address(DetfFacetFactoryService.deployRebasingClaimTokenFacet(create3Factory)),
            address(current), "identical release remains idempotent"
        );
    }

    /// @notice A different valid facet binding creates a new package and preserves the previous one.
    function test_releaseSalt_constructorChangeCreatesNewPackage() public {
        IUniswapV4DetfDFPkg.PkgInit memory init = _releasePkgInit();
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(indexedexManager));
        vm.startPrank(owner);
        IUniswapV4DetfDFPkg unchanged = UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(reg, init);
        vm.stopPrank();
        assertEq(address(unchanged), address(detfPkg), "same code and constructor reuse package");

        IFacet replacement = create3Factory.deployFacet(
            vm.getCode("UniswapV4DetfBondFacet.sol:UniswapV4DetfBondFacet"),
            keccak256(abi.encode("UniswapV4DetfBondFacet", "release constructor regression"))
        );
        init.productFacets[1] = replacement;
        vm.startPrank(owner);
        IUniswapV4DetfDFPkg changed = UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(reg, init);
        IUniswapV4DetfDFPkg repeated = UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(reg, init);
        vm.stopPrank();
        assertTrue(address(changed) != address(detfPkg), "constructor change gets a new package");
        assertEq(address(repeated), address(changed), "new constructor also remains idempotent");
        assertEq(changed.facetCuts()[6].facetAddress, address(replacement), "new immutable facet binding");
        assertEq(detfPkg.facetCuts()[6].facetAddress, address(detfProductFacets[1]), "old package remains intact");
    }

    function _releasePkgInit() private view returns (IUniswapV4DetfDFPkg.PkgInit memory) {
        return IUniswapV4DetfDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            productFacets: detfProductFacets,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            syPkg: syPkg
        });
    }

    /// @notice Every independently deployed product facet fits the EVM's hard bytecode limits.
    function test_splitFacets_deployedRuntimeAndInitcodeFitLimits() public {
        for (uint256 i; i < detfProductFacets.length; ++i) {
            IFacet facet = detfProductFacets[i];
            uint256 runtimeSize = address(facet).code.length;
            assertGt(runtimeSize, 0, "facet deployed through CREATE3");
            assertLe(runtimeSize, 24_576, facet.facetName());
            string memory name = facet.facetName();
            assertLe(vm.getCode(string.concat(name, ".sol:", name)).length, 49_152, "facet initcode limit");
        }
        assertLe(address(detfPkg).code.length, 24_576, "package runtime limit");
    }

    /// @notice The funded product selectors occur once and route to the declared facet.
    function test_splitFacets_packageRoutesEachSelectorToItsFacet() public view {
        IDiamond.FacetCut[] memory cuts = detfPkg.facetCuts();
        assertEq(cuts.length, 10, "five shared facets plus five product facets");
        uint256 count;
        bytes4[] memory seen = new bytes4[](48);
        for (uint256 i; i < detfProductFacets.length; ++i) {
            assertEq(cuts[i + 5].facetAddress, address(detfProductFacets[i]), "package facet order");
            bytes4[] memory selectors = detfProductFacets[i].facetFuncs();
            assertEq(cuts[i + 5].functionSelectors.length, selectors.length, "complete role cut");
            for (uint256 j; j < selectors.length; ++j) {
                assertEq(cuts[i + 5].functionSelectors[j], selectors[j], "selector retained in cut");
                assertEq(IDiamondLoupe(detf).facetAddress(selectors[j]), address(detfProductFacets[i]), "live route");
                for (uint256 k; k < count; ++k) {
                    assertTrue(seen[k] != selectors[j], "duplicate selector");
                }
                seen[count++] = selectors[j];
            }
        }
        assertEq(count, 48, "funded product selector count");
        assertTrue(IERC165(detf).supportsInterface(type(IUniswapV4Detf).interfaceId), "composed DETF interface");
        assertTrue(
            IERC165(detf).supportsInterface(type(IStandardExchangeIn).interfaceId), "composed exchange interface"
        );
    }

    /// @notice The Crane metadata contract remains internally consistent for every role.
    function test_splitFacets_metadataConsistency() public {
        for (uint256 i; i < detfProductFacets.length; ++i) {
            assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(detfProductFacets[i]), "facet metadata");
        }
    }

    /// @notice Retired product routes cannot bypass the standard exchange or funded staking APIs.
    function test_splitFacets_retiredProductSelectorsAreAbsent() public view {
        bytes4[8] memory retired_ = [
            bytes4(keccak256("mint(address,uint256,uint256,address,bool,uint256)")),
            bytes4(keccak256("burn(uint256,address,uint256,address,uint256)")),
            bytes4(keccak256("previewMint(address,uint256)")),
            bytes4(keccak256("mintClaim(address,uint256,uint256,address,bool,uint256)")),
            bytes4(keccak256("thresholdMode()")),
            bytes4(keccak256("compoundProtocolRewards()")),
            bytes4(keccak256("compoundProtocolRewardsAtomic()")),
            bytes4(keccak256("closeBondMature(uint256,uint256[],address,uint256)"))
        ];
        for (uint256 i_; i_ < retired_.length; ++i_) {
            assertEq(IDiamondLoupe(detf).facetAddress(retired_[i_]), address(0), "retired selector installed");
        }
    }

    /// @notice Moving atomic callback wrappers preserves self-only authentication on proxy and facet.
    function test_splitFacets_atomicCallbacksRemainSelfOnly() public {
        _assertAtomicCallerRejected(detf);
        _assertAtomicCallerRejected(address(detfProductFacets[2]));
    }

    function _assertAtomicCallerRejected(address target) internal {
        bytes memory expectedError_ = abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, address(this));
        vm.expectRevert(expectedError_);
        IUniswapV4DetfSelfCall(target).sweepDustAtomic();
        vm.expectRevert(expectedError_);
        IUniswapV4DetfSelfCall(target).sweepPairToShare(address(0), address(0), 1);
    }
}
