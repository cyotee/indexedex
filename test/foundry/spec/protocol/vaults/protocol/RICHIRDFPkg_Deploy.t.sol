// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {IRICHIRDFPkg, RICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";

contract RICHIRDFPkg_Deploy_Test is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using BaseProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;

    IRICHIRDFPkg internal pkg;

    function setUp() public override {
        super.setUp();

        IFacet richirFacet = create3Factory.deployRICHIRFacet();

        IRICHIRDFPkg.PkgInit memory pkgInit = IRICHIRDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            richirFacet: richirFacet,
            diamondFactory: diamondPackageFactory
        });

        // NOTE: RICHIRDFPkg is NOT an IStandardVaultPkg, so it must NOT be deployed via VaultRegistryDeployment.
        pkg = IRICHIRDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RICHIRDFPkg).creationCode, abi.encode(pkgInit), abi.encode(type(RICHIRDFPkg).name)._hash()
                )
            )
        );

        assertGt(address(pkg).code.length, 0, "RICHIRDFPkg not deployed");
    }

    function test_deployToken_success() public {
        address mockWeth = create3Factory.create3WithArgs(
            type(ERC20PermitMintableStub).creationCode,
            abi.encode("Mock WETH", "mWETH", uint8(18), owner, uint256(0)),
            keccak256("RICHIR_MockWeth")
        );

        address tokenAddr = pkg.deployToken(
            IProtocolDETF(address(0xBEEF)), IProtocolNFTVault(address(0xCAFE)), IERC20(mockWeth), 1, owner
        );

        assertGt(tokenAddr.code.length, 0, "RICHIR proxy not deployed");
        assertEq(IRICHIR(tokenAddr).protocolDETF(), address(0xBEEF), "protocolDETF mismatch");
    }

    function test_deployToken_returnsExisting_onDuplicateSalt() public {
        address mockWeth = create3Factory.create3WithArgs(
            type(ERC20PermitMintableStub).creationCode,
            abi.encode("Mock WETH", "mWETH", uint8(18), owner, uint256(0)),
            keccak256("RICHIR_MockWeth2")
        );

        address tokenAddr1 = pkg.deployToken(
            IProtocolDETF(address(0xBEEF)), IProtocolNFTVault(address(0xCAFE)), IERC20(mockWeth), 1, owner
        );

        // Same protocolDETF => same optionalSalt => deterministic address collision.
        // The factory returns the existing deployment instead of reverting.
        address tokenAddr2 = pkg.deployToken(
            IProtocolDETF(address(0xBEEF)), IProtocolNFTVault(address(0xCAFE)), IERC20(mockWeth), 1, owner
        );

        assertEq(tokenAddr2, tokenAddr1, "expected existing deployment");
        assertGt(tokenAddr2.code.length, 0, "RICHIR proxy not deployed");
    }
}
