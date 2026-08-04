// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {
    AaveCrossVersionLoopDFPkg,
    IAaveCrossVersionLoopDFPkg
} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol";

/// @dev Minimal VaultRegistry stub that records the deployVault call and returns a sentinel.
contract _MockRegistry is IVaultRegistryDeployment {
    address public lastVault;
    bytes public lastArgs;

    function deployPkg(bytes calldata, bytes calldata, bytes32) external pure returns (address) {
        return address(0);
    }

    function deployVault(IStandardVaultPkg, bytes calldata pkgArgs) external returns (address) {
        lastArgs = pkgArgs;
        lastVault = address(0xBEEF);
        return lastVault;
    }

    function deployHookVault(IStandardVaultPkg, bytes calldata, uint256) external pure returns (address) {
        return address(0);
    }

    function deployHookVaultAutoMine(IStandardVaultPkg, bytes calldata) external pure returns (address) {
        return address(0);
    }

    function setHookDiamondPackageFactory(address) external pure {}
}

/**
 * @title AaveCrossVersionLoopDFPkg_Test
 * @notice Validates the DFPkg deploy-time pair validation (PRD: reverts on pairs not usable on BOTH
 *         versions) and that a valid pair is routed through the VaultRegistry deployment path.
 */
contract AaveCrossVersionLoopDFPkg_Test is TestBase_AaveCrossVersionLoopV3Market {
    AaveCrossVersionLoopDFPkg internal dfpkg;
    _MockRegistry internal registry;

    function _deployDFPkg() internal {
        registry = new _MockRegistry();

        IAaveCrossVersionLoopDFPkg.PkgInit memory pkgInit = IAaveCrossVersionLoopDFPkg.PkgInit({
            erc20Facet: IFacet(address(0)),
            erc5267Facet: IFacet(address(0)),
            erc2612Facet: IFacet(address(0)),
            multiAssetBasicVaultFacet: IFacet(address(0)),
            multiAssetStandardVaultFacet: IFacet(address(0)),
            exchangeInFacet: IFacet(address(0)),
            exchangeOutFacet: IFacet(address(0)),
            rebalanceFacet: IFacet(address(0)),
            markerFacet: IFacet(address(0)),
            v36Pool: v36Pool,
            v36AddressesProvider: IPoolAddressesProvider(v36AddressesProvider),
            v36Oracle: IAaveOracle(v36Oracle),
            v4Spoke: v4Spoke,
            v4Hub: v4Hub,
            v4Oracle: IAaveOracleV4(address(v4Oracle)),
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(0)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(registry)),
            permit2: IPermit2(address(0))
        });

        // Deploy via CREATE3 factory per standards (never `new` for DFPkgs).
        // This exercises the package deployment path even for this isolated logic test.
        dfpkg = AaveCrossVersionLoopDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(AaveCrossVersionLoopDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256(abi.encode(type(AaveCrossVersionLoopDFPkg).name))
                )
            )
        );
        vm.label(address(dfpkg), "AaveCrossVersionLoopDFPkg");
    }

    function test_deployVault_validPair_routesToRegistry() public {
        _deployDFPkg();
        // tokenA/tokenB are listed + usable on both versions (the harness configured them).
        address vault = dfpkg.deployVault(tokenA, tokenB);
        assertEq(vault, address(0xBEEF), "routed through registry");
        assertEq(registry.lastVault(), address(0xBEEF), "registry recorded deployment");
    }

    function test_deployVault_unlistedToken_revertsV3() public {
        _deployDFPkg();
        // A freshly deployed token is not listed on Aave -> not usable on V3.
        IERC20 stray = IERC20(testTokenPkg.deployToken("Stray", "STRAY", 18, address(this), keccak256("STRAY")));
        vm.expectRevert(abi.encodeWithSelector(IAaveCrossVersionLoopDFPkg.TokenNotUsableOnV3.selector, address(stray)));
        dfpkg.deployVault(stray, tokenB);
    }

    function test_deployVault_zeroOrIdentical_reverts() public {
        _deployDFPkg();
        vm.expectRevert();
        dfpkg.deployVault(tokenA, tokenA);
        vm.expectRevert();
        dfpkg.deployVault(IERC20(address(0)), tokenB);
    }
}
