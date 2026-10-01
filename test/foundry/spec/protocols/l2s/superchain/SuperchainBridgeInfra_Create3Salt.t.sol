// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {DeployPermit2} from "@crane/contracts/protocols/utils/permit2/test/utils/DeployPermit2.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondFactoryPackageRegistry} from "@crane/contracts/registries/package/IDiamondFactoryPackageRegistry.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {Creation} from "@crane/contracts/utils/Creation.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    ApprovedMessageSenderRegistryFactoryService
} from "@crane/contracts/protocols/l2s/superchain/registries/message/sender/ApprovedMessageSenderRegistryFactoryService.sol";
import {
    ApprovedMessageSenderRegistryDFPkg
} from "@crane/contracts/protocols/l2s/superchain/registries/message/sender/ApprovedMessageSenderRegistryDFPkg.sol";
import {
    SuperChainBridgeTokenRegistryFactoryService
} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/SuperChainBridgeTokenRegistryFactoryService.sol";
import {
    SuperChainBridgeTokenRegistryDFPkg
} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/SuperChainBridgeTokenRegistryDFPkg.sol";
import {
    TokenTransferRelayerFactoryService
} from "@crane/contracts/protocols/l2s/superchain/relayers/token/TokenTransferRelayerFactoryService.sol";
import {
    TokenTransferRelayerDFPkg
} from "@crane/contracts/protocols/l2s/superchain/relayers/token/TokenTransferRelayerDFPkg.sol";

/// @notice Hermetic evidence for Crane helpers and Script 24's component identities; no script execution.
contract SuperchainBridgeInfra_Create3Salt is IndexedexTest, DeployPermit2 {
    using BetterEfficientHashLib for bytes;
    IFacet private operable;
    IFacet private alternateOwnable;
    IPermit2 private bridgePermit2;

    function setUp() public override {
        IndexedexTest.setUp();
        bridgePermit2 = IPermit2(deployPermit2());
        operable = AccessFacetFactoryService.deployOperableFacet(create3Factory);
        alternateOwnable = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MultiStepOwnableFacet.sol:MultiStepOwnableFacet"),
            abi.encode("SuperchainBridgeInfra_Create3Salt.alternateOwnable")._hash()
        );
    }

    /// @notice ApprovedMessageSenderRegistryDFPkg keeps its first constructor bindings at its canonical identity.
    function test_ApprovedMessageSenderRegistry_identityBindingsAndReuse() public {
        IFacet facet =
            ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistryFacet(create3Factory);
        ApprovedMessageSenderRegistryDFPkg pkg = ApprovedMessageSenderRegistryDFPkg(
            address(
                ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistryDFPkg(
                    create3Factory, multiStepOwnableFacet, operable, facet
                )
            )
        );
        bytes32 salt = abi.encode(type(ApprovedMessageSenderRegistryDFPkg).name)._hash();
        // Script 24 uses this literal expression; it is deliberately not imported or executed.
        assertEq(salt, abi.encode("ApprovedMessageSenderRegistryDFPkg")._hash());
        assertEq(address(pkg), Creation._create3AddressFromOf(address(create3Factory), salt));
        assertEq(address(pkg.OWNABLE_FACET()), address(multiStepOwnableFacet));
        assertEq(address(pkg.APPROVED_MESSAGE_SENDER_REGISTRY_FACET()), address(facet));
        assertEq(address(pkg.OPERABLE_FACET()), address(operable));
        _assertRegistered(address(pkg), "ApprovedMessageSenderRegistryDFPkg");
        address again = address(
            ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistryDFPkg(
                create3Factory, alternateOwnable, operable, facet
            )
        );
        assertEq(again, address(pkg));
        assertEq(address(pkg.OWNABLE_FACET()), address(multiStepOwnableFacet));
        assertEq(address(pkg.APPROVED_MESSAGE_SENDER_REGISTRY_FACET()), address(facet));
        assertEq(address(pkg.OPERABLE_FACET()), address(operable));
    }

    /// @notice SuperChainBridgeTokenRegistryDFPkg keeps its first constructor bindings at its canonical identity.
    function test_SuperChainBridgeTokenRegistry_identityBindingsAndReuse() public {
        IFacet facet =
            SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryFacet(create3Factory);
        SuperChainBridgeTokenRegistryDFPkg pkg = SuperChainBridgeTokenRegistryDFPkg(
            address(
                SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryDFPkg(
                    create3Factory, multiStepOwnableFacet, operable, facet
                )
            )
        );
        bytes32 salt = abi.encode(type(SuperChainBridgeTokenRegistryDFPkg).name)._hash();
        // Script 24 uses this literal expression; it is deliberately not imported or executed.
        assertEq(salt, abi.encode("SuperChainBridgeTokenRegistryDFPkg")._hash());
        assertEq(address(pkg), Creation._create3AddressFromOf(address(create3Factory), salt));
        assertEq(address(pkg.OWNABLE_FACET()), address(multiStepOwnableFacet));
        assertEq(address(pkg.SUPER_CHAIN_BRIDGE_TOKEN_REGISTRY_FACET()), address(facet));
        assertEq(address(pkg.OPERABLE_FACET()), address(operable));
        _assertRegistered(address(pkg), "SuperChainBridgeTokenRegistryDFPkg");
        address again = address(
            SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryDFPkg(
                create3Factory, alternateOwnable, operable, facet
            )
        );
        assertEq(again, address(pkg));
        assertEq(address(pkg.OWNABLE_FACET()), address(multiStepOwnableFacet));
        assertEq(address(pkg.SUPER_CHAIN_BRIDGE_TOKEN_REGISTRY_FACET()), address(facet));
        assertEq(address(pkg.OPERABLE_FACET()), address(operable));
    }

    /// @notice TokenTransferRelayerDFPkg keeps its first constructor bindings at its canonical identity.
    function test_TokenTransferRelayer_identityBindingsAndReuse() public {
        IFacet facet = TokenTransferRelayerFactoryService.deployTokenTransferRelayerFacet(create3Factory);
        TokenTransferRelayerDFPkg pkg = TokenTransferRelayerDFPkg(
            address(
                TokenTransferRelayerFactoryService.deployTokenTransferRelayerDFPkg(
                    create3Factory, multiStepOwnableFacet, facet, bridgePermit2
                )
            )
        );
        bytes32 salt = abi.encode(type(TokenTransferRelayerDFPkg).name)._hash();
        // Script 24 uses this literal expression; it is deliberately not imported or executed.
        assertEq(salt, abi.encode("TokenTransferRelayerDFPkg")._hash());
        assertEq(address(pkg), Creation._create3AddressFromOf(address(create3Factory), salt));
        assertEq(address(pkg.OWNABLE_FACET()), address(multiStepOwnableFacet));
        assertEq(address(pkg.TOKEN_TRANSFER_RELAYER_FACET()), address(facet));
        assertEq(address(pkg.PERMIT2()), address(bridgePermit2));
        _assertRegistered(address(pkg), "TokenTransferRelayerDFPkg");
        address again = address(
            TokenTransferRelayerFactoryService.deployTokenTransferRelayerDFPkg(
                create3Factory, alternateOwnable, facet, bridgePermit2
            )
        );
        assertEq(again, address(pkg));
        assertEq(address(pkg.OWNABLE_FACET()), address(multiStepOwnableFacet));
        assertEq(address(pkg.TOKEN_TRANSFER_RELAYER_FACET()), address(facet));
        assertEq(address(pkg.PERMIT2()), address(bridgePermit2));
    }

    function _assertRegistered(address pkg, string memory name) private view {
        IDiamondFactoryPackageRegistry registry = IDiamondFactoryPackageRegistry(address(create3Factory));
        address[] memory packages = registry.packagesByName(name);
        bool found;
        for (uint256 i; i < packages.length; ++i) {
            if (packages[i] == pkg) found = true;
        }
        assertTrue(found, "CREATE3 package registered");
    }
}
