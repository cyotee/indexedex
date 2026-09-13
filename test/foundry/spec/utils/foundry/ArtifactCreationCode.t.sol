// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

/// @notice Exercise actual production artifacts without importing their implementations.
contract ArtifactCreationCode_Test is CraneTest {
    string internal constant SE_FACET =
        "UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol:UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet";
    string internal constant MATH = "UniswapV4SingleStandardExchangeBufferConstantProductHookMath";
    string internal constant MATH_SOURCE =
        "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";

    /// @notice A component absent from the test import graph still deploys from its artifact.
    function test_loadWithoutImplementationImport() public {
        bytes memory code_ = ArtifactCreationCode.creationCode("FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet");
        address deployed_ = address(create3Factory.deployFacet(code_, keccak256("ArtifactCreationCode.unlinked")));
        assertEq(IFacet(deployed_).facetName(), "FeeCollectorManagerFacet");
        assertGt(deployed_.code.length, 0);
    }

    /// @notice Linked library addresses refer to executable real math; repeat loads are deterministic.
    function test_linkedLibrariesExecuteAndAreReused() public {
        bytes memory code_ = ArtifactCreationCode.creationCode(create3Factory, SE_FACET);
        string memory json_ = vm.readFile(
            string.concat(
                vm.projectRoot(),
                "/out/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.json"
            )
        );
        uint256 offset_ = vm.parseJsonUint(
            json_, string.concat('.bytecode.linkReferences["', MATH_SOURCE, '"]["', MATH, '"][0].start')
        );
        address math_ = _linkedAddress(code_, offset_);
        assertGt(math_.code.length, 0);
        (bool success_, bytes memory result_) =
            math_.staticcall(abi.encodeWithSignature("toWad(uint256,uint8)", 123, 6));
        assertTrue(success_);
        assertEq(abi.decode(result_, (uint256)), 123e12);
        bytes32 runtimeHash_ = math_.codehash;
        assertEq(keccak256(ArtifactCreationCode.creationCode(create3Factory, SE_FACET)), keccak256(code_));
        assertEq(math_.codehash, runtimeHash_);
    }

    /// @notice Recursively linked production code contains no unresolved placeholders and deploys.
    function test_nestedLibraryLinksDeploy() public {
        bytes memory code_ = ArtifactCreationCode.creationCode(
            create3Factory,
            "UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet.sol:UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet"
        );
        address deployed_ = address(create3Factory.deployFacet(code_, keccak256("ArtifactCreationCode.nested")));
        assertEq(IFacet(deployed_).facetName(), "UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet");
    }

    /// @notice Full source identifiers resolve to the same artifact as unique short identifiers.
    function test_fullSourceIdentifier() public {
        assertEq(
            ArtifactCreationCode.creationCode(
                "contracts/fee/collector/FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet"
            ),
            ArtifactCreationCode.creationCode("FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet")
        );
    }

    /// @notice An artifact for a different source cannot satisfy a qualified identifier.
    function test_fullSourceDoesNotFallBackToDifferentImplementation() public {
        string memory id_ = "different/source/FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet";
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", string.concat("ArtifactCreationCode: missing artifact ", id_))
        );
        this.loadWithoutFactory(id_);
    }

    /// @notice A linked artifact requires a factory instead of returning unusable bytes.
    function test_unlinkedArtifactRequiresFactory() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)", string.concat("ArtifactCreationCode: linking requires factory ", SE_FACET)
            )
        );
        this.loadWithoutFactory(SE_FACET);
    }

    /// @notice Missing bytecode fails before a CREATE3 deployment can occur.
    function test_missingArtifactFails() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)", "ArtifactCreationCode: missing artifact MissingArtifact.sol:MissingArtifact"
            )
        );
        this.loadWithoutFactory("MissingArtifact.sol:MissingArtifact");
    }

    /// @notice Invalid identifiers fail explicitly.
    function test_invalidIdentifierFails() public {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "ArtifactCreationCode: expected File.sol:Contract"));
        this.loadWithoutFactory("missing-separator");
    }

    /// @notice Abstract production targets cannot accidentally be deployed as empty code.
    function test_emptyArtifactFails() public {
        string memory id_ =
            "UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget";
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", string.concat("ArtifactCreationCode: empty bytecode ", id_))
        );
        this.loadWithoutFactory(id_);
    }

    /// @notice External boundary for exact revert assertions around Foundry file operations.
    function loadWithoutFactory(string memory artifactId_) external returns (bytes memory) {
        return ArtifactCreationCode.creationCode(artifactId_);
    }

    function _linkedAddress(bytes memory code_, uint256 offset_) private pure returns (address linked_) {
        assembly ("memory-safe") {
            linked_ := shr(96, mload(add(add(code_, 32), offset_)))
        }
    }
}
