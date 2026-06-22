// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {IAaveCrossVersionLoopDFPkg, AaveCrossVersionLoopDFPkg} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol";
import {AaveCrossVersionLoop_Component_FactoryService} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol";

/**
 * @title AaveCrossVersionLoopE2E_Test
 * @notice End-to-end: deploys the facets via CREATE3, registers the DFPkg through the IndexedexManager
 *         + VaultRegistry, `deployVault(tokenA, tokenB)` to mint a real diamond proxy, then operates
 *         it via its IStandardExchange selectors against the live local cross-version markets. This is
 *         the full IndexedEx deployment path (PRD architecture).
 */
contract AaveCrossVersionLoopE2E_Test is TestBase_AaveCrossVersionLoopV3Market {
    using AaveCrossVersionLoop_Component_FactoryService for ICreate3FactoryProxy;
    using AaveCrossVersionLoop_Component_FactoryService for IIndexedexManagerProxy;

    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);
    address internal vault;

    function _deployVaultThroughRegistry() internal {
        IFacet inFacet = create3Factory.deployExchangeInFacet();
        IFacet outFacet = create3Factory.deployExchangeOutFacet();
        IFacet rebalFacet = create3Factory.deployRebalanceFacet();
        IFacet markerFacet = create3Factory.deployMarkerFacet();

        AaveCrossVersionLoopDFPkg.PkgInit memory pkgInit = IAaveCrossVersionLoopDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: inFacet,
            exchangeOutFacet: outFacet,
            rebalanceFacet: rebalFacet,
            markerFacet: markerFacet,
            v36Pool: v36Pool,
            v36AddressesProvider: IPoolAddressesProvider(v36AddressesProvider),
            v36Oracle: IAaveOracle(v36Oracle),
            v4Spoke: v4Spoke,
            v4Hub: v4Hub,
            v4Oracle: IAaveOracleV4(address(v4Oracle)),
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            permit2: IPermit2(address(0))
        });

        vm.prank(owner);
        AaveCrossVersionLoopDFPkg dfpkg = indexedexManager.deployCrossVersionLoopDFPkg(pkgInit);

        vm.prank(owner);
        vault = dfpkg.deployVault(tokenA, tokenB);
    }

    function _seedBorrowLiquidity() internal {
        _mint(tokenB, v3lp, 2_000_000e6);
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), 2_000_000e6);
        v36Pool.supply(address(tokenB), 2_000_000e6, v3lp, 0);
        vm.stopPrank();

        _mint(tokenA, v4lp, 1_000e18);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), 1_000e18);
        v4Spoke.supply(v4ReserveIdA, 1_000e18, v4lp);
        vm.stopPrank();
    }

    function test_deploy_through_registry_and_operate() public {
        _deployVaultThroughRegistry();
        assertTrue(vault != address(0), "vault deployed via registry");
        _seedBorrowLiquidity();

        // Deposit through the deployed diamond's IStandardExchangeIn selector.
        uint256 deposit = 100e18;
        _mint(tokenA, address(this), deposit);
        tokenA.approve(vault, deposit);
        uint256 shares = IStandardExchangeIn(vault).exchangeIn(
            tokenA, deposit, IERC20(vault), 0, address(this), false, block.timestamp
        );

        // Shares minted on the diamond's ERC20; leveraged cross-version position built on the vault.
        assertGt(shares, 0, "shares minted");
        assertEq(IERC20(vault).balanceOf(address(this)), shares, "holder holds shares");
        assertGt(
            AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), deposit, "vault leveraged on V3"
        );
        assertGt(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), 0, "vault borrowed A on V4");
        assertGt(AaveV36Service.healthFactor(v36Pool, vault), 1e18, "vault V3 HF > 1");
        assertGt(AaveV4Service.healthFactor(v4Spoke, vault), 1e18, "vault V4 HF > 1");

        // Partial withdraw through the diamond's IStandardExchangeOut selector.
        uint256 balBefore = tokenA.balanceOf(address(this));
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, 2e18, address(this), false, block.timestamp
        );
        assertEq(tokenA.balanceOf(address(this)) - balBefore, 2e18, "withdrew tokenA via diamond");
    }

    function test_deployVault_marker_exposes_pair_and_sources() public {
        _deployVaultThroughRegistry();
        // Marker views resolve on the deployed diamond.
        assertEq(address(IMarker(vault).tokenA()), address(tokenA), "marker tokenA");
        assertEq(address(IMarker(vault).tokenB()), address(tokenB), "marker tokenB");
        assertEq(IMarker(vault).aaveV36Pool(), address(v36Pool), "marker V3 pool");
        assertEq(IMarker(vault).aaveV4Spoke(), address(v4Spoke), "marker V4 spoke");
    }
}

/// @dev Minimal marker view interface for reading the deployed diamond.
interface IMarker {
    function tokenA() external view returns (IERC20);
    function tokenB() external view returns (IERC20);
    function aaveV36Pool() external view returns (address);
    function aaveV4Spoke() external view returns (address);
}
