// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IPoolConfigurator} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolConfigurator.sol";
import {IACLManager} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IACLManager.sol";
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
import {IAaveCrossVersionLoopDFPkg} from "contracts/protocols/lending/aave/cross-version/IAaveCrossVersionLoopDFPkg.sol";
import {AaveCrossVersionLoop_Component_FactoryService} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol";

/// @notice APEX D43 / R14.6 / R14.7 / R14.12 on the registry-deployed loop diamond: the V3 tokenA
///         supply cap stops the loop, retains the partial position, books unsupplied principal
///         locally, counts it in NAV and pays it first.
contract AaveCrossVersionLoop_APEX_D43_Test is TestBase_AaveCrossVersionLoopV3Market {
    using AaveCrossVersionLoop_Component_FactoryService for ICreate3FactoryProxy;
    using AaveCrossVersionLoop_Component_FactoryService for IIndexedexManagerProxy;

    address internal vault;
    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);

    function _initVault() internal {
        IFacet inFacet = create3Factory.deployExchangeInFacet();
        IFacet outFacet = create3Factory.deployExchangeOutFacet();
        IFacet rebalFacet = create3Factory.deployRebalanceFacet();
        IFacet markerFacet = create3Factory.deployMarkerFacet();
        IFacet transitionQuoteFacet = create3Factory.deployTransitionQuoteFacet();
        IAaveCrossVersionLoopDFPkg.PkgInit memory pkgInit = IAaveCrossVersionLoopDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: inFacet,
            exchangeOutFacet: outFacet,
            rebalanceFacet: rebalFacet,
            markerFacet: markerFacet,
            transitionQuoteFacet: transitionQuoteFacet,
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
        IAaveCrossVersionLoopDFPkg dfpkg = indexedexManager.deployCrossVersionLoopDFPkg(pkgInit);
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

    function _setSupplyCapA(uint256 wholeTokens) internal {
        IACLManager(v36AclManager).addPoolAdmin(address(this));
        IPoolConfigurator(v36PoolConfigurator).setSupplyCap(address(tokenA), wholeTokens);
    }

    function _deposit(uint256 amount) internal returns (uint256 shares) {
        _mint(tokenA, address(this), amount);
        tokenA.approve(vault, amount);
        shares = IStandardExchangeIn(vault).exchangeIn(tokenA, amount, IERC20(vault), 0, address(this), false, block.timestamp);
    }

    /// @dev R14.7: 100 principal with 150 of headroom supplies 100, then the recursive legs are
    ///      clamped to the remaining 50 (39.69 + 10.31); no borrowed tokenA is left idle.
    function test_APEX_D43_capReachedInLaterIteration_retainsPartialPosition() public {
        _initVault();
        _seedBorrowLiquidity();
        _setSupplyCapA(150);
        uint256 shares = _deposit(100e18);
        assertGt(shares, 0);
        uint256 suppliedA = AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault);
        assertApproxEqAbs(suppliedA, 150e18, 1e12, "supply stopped exactly at the cap");
        uint256 debtA = AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault);
        assertApproxEqAbs(debtA, 50e18, 1e12, "recursive tokenA debt equals the clamped legs");
        assertEq(tokenA.balanceOf(vault), 0, "no idle borrowed tokenA");
        assertGt(AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, vault), 0, "tokenB collateral retained");
        assertGt(AaveV36Service.healthFactor(v36Pool, vault), 1e18);
    }

    /// @dev R14.2/R14.12: zero initial capacity books the whole principal locally, NAV counts it,
    ///      a later exit pays from the local balance first, and reopening the cap sweeps it (D31).
    function test_APEX_D43_zeroCapacity_booksPrincipal_navAndExitLocalFirst_thenSweep() public {
        _initVault();
        _seedBorrowLiquidity();
        uint256 first = _deposit(100e18); // open cap: full loop
        _setSupplyCapA(1); // below current supply → capacity 0
        uint256 preview = IStandardExchangeIn(vault).previewExchangeIn(tokenA, 20e18, IERC20(vault));
        uint256 suppliedBefore = AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault);
        uint256 second = _deposit(20e18);
        assertEq(second, preview, "preview equals execution");
        assertEq(tokenA.balanceOf(vault), 20e18, "principal retained locally");
        assertEq(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), suppliedBefore, "no supply at cap");
        // Local principal is part of NAV: the second depositor's shares reflect its full value.
        assertApproxEqRel(second, (first * 20) / 100, 0.02e18, "shares priced on NAV including local tokenA");
        // Exit 5 tokenA: paid from local first, V3 supply untouched.
        uint256 sharesFor5 = IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, 5e18);
        uint256 balBefore = tokenA.balanceOf(address(this));
        IStandardExchangeOut(vault).exchangeOut(IERC20(vault), sharesFor5, tokenA, 5e18, address(this), false, block.timestamp);
        assertEq(tokenA.balanceOf(address(this)) - balBefore, 5e18, "exact output");
        assertEq(tokenA.balanceOf(vault), 15e18, "paid from local first");
        assertEq(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), suppliedBefore, "no V3 withdrawal needed");
        // Reopen: the next deposit sweeps the retained 15 before the caller's principal (D31).
        _setSupplyCapA(0);
        _deposit(1e18);
        assertEq(tokenA.balanceOf(vault), 0, "retained principal swept into the loop");
        assertGt(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), suppliedBefore + 15e18, "swept and looped");
    }
}
