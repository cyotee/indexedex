// SPDX-License-Identifier: BSL-1.1
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
import {
    AaveCrossVersionLoopDFPkg,
    IAaveCrossVersionLoopDFPkg
} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";

/// @dev Minimal VaultRegistry stub that records the deployVault call (gold clone).
contract _MockRegistryDecimals is IVaultRegistryDeployment {
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

/// @notice DFPkg pair-validation money paths on each two-token combo. pairToken = tokenA.
abstract contract AaveCrossVersionLoopDFPkg_Decimals is TestBase_AaveCrossVersionLoopV3Market_Decimals {
    AaveCrossVersionLoopDFPkg internal dfpkg;
    _MockRegistryDecimals internal registry;

    function _deployDFPkg() internal {
        registry = new _MockRegistryDecimals();

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

        dfpkg = AaveCrossVersionLoopDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(AaveCrossVersionLoopDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256(abi.encode(type(AaveCrossVersionLoopDFPkg).name, _tokenADecimals(), _tokenBDecimals()))
                )
            )
        );
        vm.label(address(dfpkg), "AaveCrossVersionLoopDFPkg");
    }

    function test_deployVault_validPair_routesToRegistry() public {
        _deployDFPkg();
        address vault = dfpkg.deployVault(tokenA, tokenB);
        assertEq(vault, address(0xBEEF), "routed through registry");
        assertEq(registry.lastVault(), address(0xBEEF), "registry recorded deployment");
    }

    function test_deployVault_unlistedToken_revertsV3() public {
        _deployDFPkg();
        IERC20 stray = IERC20(
            testTokenPkg.deployToken("Stray", "STRAY", 18, address(this), keccak256(abi.encode("STRAY", _tokenADecimals())))
        );
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
