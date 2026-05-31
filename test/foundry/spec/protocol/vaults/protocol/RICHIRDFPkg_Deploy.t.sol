// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {IRICHIRDFPkg, RICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/reusable/DetfFacetFactoryService.sol";

contract RICHIRDFPkg_Deploy_Test is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using DetfFacetFactoryService for ICreate3FactoryProxy;

    IRICHIRDFPkg internal pkg;
    ERC20PermitDFPkg internal erc20PermitPkg;

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

        erc20PermitPkg = _deployTestTokenPkg();

        assertGt(address(pkg).code.length, 0, "RICHIRDFPkg not deployed");
    }

    function test_deployToken_success() public {
        address mockWeth = address(_deployTestToken("Mock WETH", "mWETH", keccak256("RICHIR_MockWeth")));

        address tokenAddr = pkg.deployToken(
            IProtocolDETF(address(0xBEEF)), IProtocolNFTVault(address(0xCAFE)), IERC20(mockWeth), 1, owner
        );

        assertGt(tokenAddr.code.length, 0, "RICHIR proxy not deployed");
        assertEq(IRICHIR(tokenAddr).protocolDETF(), address(0xBEEF), "protocolDETF mismatch");
    }

    function test_deployToken_returnsExisting_onDuplicateSalt() public {
        address mockWeth = address(_deployTestToken("Mock WETH", "mWETH", keccak256("RICHIR_MockWeth2")));

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

    function _deployTestTokenPkg() internal returns (ERC20PermitDFPkg pkg_) {
        IERC20PermitDFPkg.PkgInit memory pkgInit = IERC20PermitDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet
        });

        pkg_ = ERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "RICHIRDeploy"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_) internal returns (IERC20 token_) {
        IERC20PermitDFPkg.PkgArgs memory pkgArgs = IERC20PermitDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            decimals: 18,
            totalSupply: 0,
            recipient: address(0),
            optionalSalt: salt_
        });

        token_ = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc20PermitPkg)), abi.encode(pkgArgs)));
    }
}
